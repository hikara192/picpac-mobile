import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

import 'package:api_contract/api_contract.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:picpac_mobile/app/app.dart';
import 'package:picpac_mobile/app/bootstrap.dart';
import 'package:picpac_mobile/app/di.dart';
import 'package:picpac_mobile/app/env.dart';
import 'package:picpac_mobile/app/router.dart';
import 'package:picpac_mobile/core/media/photo_format.dart';
import 'package:picpac_mobile/features/_shared/application/design_session.dart';
import 'package:picpac_mobile/features/_shared/application/media_providers.dart';
import 'package:picpac_mobile/features/_shared/presentation/sheet_scene.dart';
import 'package:picpac_mobile/render/asset_image_store.dart';
import 'package:picpac_mobile/render/pdf_exporter.dart';
import 'package:riverpod/misc.dart' show Override;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('10 фото: первый кадр, 120 кадров жеста, память, 10 листов PDF', (
    tester,
  ) async {
    final dependencies = await bootstrap(
      env: const AppEnv(apiMode: ApiMode.embedded, flavor: AppFlavor.dev),
    );
    addTearDown(dependencies.dispose);
    await dependencies.tokens.clear();

    final api = dependencies.api;
    final login = await api.login(
      const LoginRequest(email: 'customer@picpac.test', password: 'Test1234'),
    );
    expect(login.isOk, isTrue, reason: '${login.failureOrNull}');

    final directory = await Directory.systemTemp.createTemp('picpac-perf');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final files = <File>[];
    for (var index = 0; index < 10; index++) {
      files.add(await _writePng(directory, 'p$index.png', tint: index * 9));
    }

    final created = await api.createDesign(
      DesignDocument.start(
        product: const DocumentProduct(id: 'photo_print', formatId: '10x15'),
      ),
    );
    final designId = created.requireValue.id;
    final catalog = await api.catalog();
    final format = catalog.requireValue.products.first.formats.first;

    final assets = <PhotoAsset>[];
    for (var index = 0; index < files.length; index++) {
      final bytes = await files[index].readAsBytes();
      assets.add(
        PhotoAsset(
          id: 'perf_$index',
          sha256: sha256.convert(bytes).toString(),
          widthPx: 1200,
          heightPx: 900,
          mimeType: PhotoFormats.png,
          bytes: bytes.length,
        ),
      );
    }
    final document =
        AutoLayoutSheets(template: format.templates.first.toPrintTemplate())
            .applyCore(
              DesignDocument(
                product: const DocumentProduct(
                  id: 'photo_print',
                  formatId: '10x15',
                ),
                assets: assets,
              ),
            );
    expect(document.spreads, hasLength(10), reason: '10 листов по одному фото');
    final put = await api.putDesign(designId, document, ifMatchRevision: 1);
    expect(put.isOk, isTrue, reason: '${put.failureOrNull}');

    runApp(
      ProviderScope(
        overrides: <Override>[
          ...appOverrides(
            env: dependencies.env,
            api: api,
            tokens: dependencies.tokens,
            database: dependencies.database,
          ),
        ],
        child: PicPacApp(env: dependencies.env),
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
      listen: false,
    );
    final appCache = container.read(designAssetCacheProvider);
    for (var index = 0; index < files.length; index++) {
      await appCache.store(
        designId: designId,
        sha256: assets[index].sha256,
        source: files[index],
      );
    }

    final firstHash = assets.first.sha256;
    final startedAt = DateTime.now();
    container.read(routerProvider).go(AppRoutes.editorFor(designId));
    var sheetMs = -1;
    var photoMs = -1;
    AssetImageStore? store;
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 16));
      final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
      if (sheetMs < 0 && find.byType(SheetScene).evaluate().isNotEmpty) {
        sheetMs = elapsed;
        final scene = tester.widget<SheetScene>(find.byType(SheetScene).first);
        store = container.read(
          assetImageStoreProvider((designId: designId, maxSide: scene.maxSide)),
        );
      }
      if (store != null && store.isLoaded(firstHash)) {
        photoMs = elapsed;
        break;
      }
    }
    expect(
      photoMs,
      greaterThanOrEqualTo(0),
      reason: 'первый кадр листа не наступил за 60 с',
    );
    _print('editor.first_sheet_ms=$sheetMs');
    _print('editor.first_photo_ms=$photoMs');

    final session = await _sessionOf(tester, container, designId);
    final spread = session.spreads.first;
    final slot = spread.slots.first;
    final controller = container.read(designSessionProvider(designId).notifier);
    controller.selectSlot(spread.id, slot.id);
    controller.execute(
      SetCrop(
        spreadId: spread.id,
        slotId: slot.id,
        crop: slot.crop,
        zoom: 2,
        anchor: NormalizedPoint.center,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final timings = <FrameTiming>[];
    void collect(List<FrameTiming> batch) => timings.addAll(batch);
    SchedulerBinding.instance.addTimingsCallback(collect);

    final scene = tester.getRect(find.byType(SheetScene));
    final gesture = await tester.startGesture(scene.center);
    await tester.pump();
    for (var frame = 0; frame < 120; frame++) {
      await gesture.moveBy(const Offset(2, 1));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));
    SchedulerBinding.instance.removeTimingsCallback(collect);

    _reportFrames(timings);

    _reportMemory();

    final images = AssetImageStore(
      cache: appCache,
      designId: designId,
      maxSide: PhotoFormats.previewMaxSide,
    );
    addTearDown(images.dispose);
    final exportStarted = DateTime.now();
    final pages = <int>[];
    final bytes = await PdfExporter.exportSheets(
      document: session.document,
      spec: session.spec,
      images: images,
      templates: session.templates,
      onProgress: (done, total) => pages.add(done),
    );
    final exportMs = DateTime.now().difference(exportStarted).inMilliseconds;
    expect(bytes.sublist(0, 5), '%PDF-'.codeUnits);
    expect(pages.last, 10);
    _print('pdf.ms=$exportMs');
    _print('pdf.bytes=${bytes.length}');
    _print('pdf.pages=${session.document.spreads.length}');
  });
}

Future<DesignSessionState> _sessionOf(
  WidgetTester tester,
  ProviderContainer container,
  String designId,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(deadline)) {
    final state = container.read(designSessionProvider(designId)).value;
    if (state != null && state.spreads.isNotEmpty) return state;
    await tester.pump(const Duration(milliseconds: 16));
  }
  fail('сессия проекта не загрузилась');
}

void _reportFrames(List<FrameTiming> timings) {
  if (timings.isEmpty) {
    _print(
      'frames.n=0 (FrameTiming не пришёл: платформа не отдаёт его в тесте)',
    );
    return;
  }
  final total = <double>[];
  final build = <double>[];
  final raster = <double>[];
  for (final timing in timings) {
    total.add(
      (timing.buildDuration + timing.rasterDuration).inMicroseconds / 1000,
    );
    build.add(timing.buildDuration.inMicroseconds / 1000);
    raster.add(timing.rasterDuration.inMicroseconds / 1000);
  }
  _print('frames.n=${timings.length}');
  _print('frames.p50_ms=${_percentile(total, 0.5).toStringAsFixed(2)}');
  _print('frames.p95_ms=${_percentile(total, 0.95).toStringAsFixed(2)}');
  _print('frames.build_p50_ms=${_percentile(build, 0.5).toStringAsFixed(2)}');
  _print('frames.build_p95_ms=${_percentile(build, 0.95).toStringAsFixed(2)}');
  _print('frames.raster_p50_ms=${_percentile(raster, 0.5).toStringAsFixed(2)}');
  _print(
    'frames.raster_p95_ms=${_percentile(raster, 0.95).toStringAsFixed(2)}',
  );
  final p95 = _percentile(total, 0.95);
  _print(
    'frames.budget_16_7=${p95 <= 16.7 ? 'ok' : 'over (${p95.toStringAsFixed(2)} ms)'}',
  );
}

double _percentile(List<double> values, double fraction) {
  final sorted = <double>[...values]..sort();
  final index = ((sorted.length - 1) * fraction).round();
  return sorted[index];
}

void _reportMemory() {
  if (!Platform.isAndroid) {
    _print('memory.vmhwm_kb=not-measured (нет счётчика в Dart на iOS)');
    return;
  }
  try {
    final status = File('/proc/self/status').readAsLinesSync();
    for (final line in status) {
      if (line.startsWith('VmHWM:')) {
        _print('memory.vmhwm_kb=${line.split(RegExp(r'\s+'))[1]}');
        return;
      }
    }
    _print('memory.vmhwm_kb=unknown');
  } on Object catch (error) {
    _print('memory.vmhwm_kb=error:${error.runtimeType}');
  }
}

void _print(String line) {
  // ignore: avoid_print
  print('PERF $line');
}

Future<File> _writePng(
  Directory directory,
  String name, {
  required int tint,
}) async {
  const width = 1200;
  const height = 900;
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw.addByte(0); // filter: none
    for (var x = 0; x < width; x++) {
      raw.add(<int>[
        30 + (x * 40 ~/ width) + tint,
        40 + (y * 40 ~/ height),
        60 + tint,
        255,
      ]);
    }
  }
  final idat = ZLibEncoder().convert(raw.takeBytes());
  final png = BytesBuilder()
    ..add(const <int>[137, 80, 78, 71, 13, 10, 26, 10])
    ..add(_chunk('IHDR', <int>[..._u32(width), ..._u32(height), 8, 6, 0, 0, 0]))
    ..add(_chunk('IDAT', idat))
    ..add(_chunk('IEND', const <int>[]));
  final file = File('${directory.path}/$name');
  await file.writeAsBytes(png.takeBytes(), flush: true);
  return file;
}

List<int> _u32(int value) => <int>[
  (value >> 24) & 0xff,
  (value >> 16) & 0xff,
  (value >> 8) & 0xff,
  value & 0xff,
];

List<int> _chunk(String type, List<int> data) {
  final payload = <int>[...type.codeUnits, ...data];
  return <int>[..._u32(data.length), ...payload, ..._u32(_crc32(payload))];
}

int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}
