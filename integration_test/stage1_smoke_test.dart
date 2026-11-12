import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:picpac_mobile/app/app.dart';
import 'package:picpac_mobile/app/bootstrap.dart';
import 'package:picpac_mobile/app/di.dart';
import 'package:picpac_mobile/app/env.dart';
import 'package:picpac_mobile/app/router.dart';
import 'package:picpac_mobile/core/media/photo_picker.dart';
import 'package:picpac_mobile/features/_shared/application/design_session.dart';
import 'package:picpac_mobile/features/_shared/application/frame_analyzer.dart';
import 'package:picpac_mobile/features/_shared/application/media_providers.dart';
import 'package:riverpod/misc.dart' show Override;

import 'support/fixture_bytes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HEIC → 10 фото → улучшение → 4 листа → 5,20 BYN → заказ', (
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

    final created = await api.createDesign(
      DesignDocument.start(
        product: const DocumentProduct(id: 'photo_print', formatId: '10x15'),
      ),
    );
    final designId = created.requireValue.id;

    final directory = await Directory.systemTemp.createTemp('picpac-smoke');
    final files = await _fixtures(directory);
    expect(files, hasLength(10));

    final picker = _FixturePicker(files);
    runApp(
      ProviderScope(
        overrides: <Override>[
          ...appOverrides(
            env: dependencies.env,
            api: api,
            tokens: dependencies.tokens,
            database: dependencies.database,
          ),
          photoPickerProvider.overrideWithValue(picker),
        ],
        child: PicPacApp(env: dependencies.env),
      ),
    );
    await _pumpUntil(tester, find.byType(Navigator));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
      listen: false,
    );
    container.read(routerProvider).go(AppRoutes.createFor(designId));

    await _pumpUntil(tester, find.byKey(const Key('photo-add-tile')));
    final addPhotos = find.byKey(const Key('photo-add-tile'));
    await tester.ensureVisible(addPhotos);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(addPhotos);
    await _pumpUntilTrue(
      tester,
      () =>
          (container
                  .read(designSessionProvider(designId))
                  .value
                  ?.document
                  .assets
                  .length ??
              0) >=
          10,
      timeout: const Duration(seconds: 120),
    );
    await _screenshotPause(tester, 'smoke-import');

    expect(container.read(designSessionProvider(designId)).value, isNotNull);
    final analyzer = container.read(frameAnalyzerProvider);
    final cache = container.read(designAssetCacheProvider);
    final doc = container.read(designSessionProvider(designId)).value!.document;
    for (final asset in doc.assets) {
      final file = await cache.fileFor(designId, asset.sha256);
      final stats = file == null ? null : await analyzer.analyze(file.path);
      expect(stats, isNotNull, reason: 'нет статистики для ${asset.id}');
      // ignore: avoid_print
      print(
        'SMOKE analyze ${asset.id} '
        'file=${file != null} '
        'rgb=${stats?.meanR.toStringAsFixed(2)},'
        '${stats?.meanG.toStringAsFixed(2)},'
        '${stats?.meanB.toStringAsFixed(2)} '
        'chroma=${stats?.meanChroma.toStringAsFixed(2)}',
      );
    }

    await _reveal(tester, find.text('Улучшить все'));
    await tester.tap(find.text('Улучшить все'));
    await _pumpUntil(
      tester,
      find.textContaining(RegExp('Улучшено|уже улучшено')),
      timeout: const Duration(seconds: 90),
    );

    await _reveal(tester, find.text('Так лучше'));
    await tester.tap(find.text('Так лучше'));
    await _pumpUntil(
      tester,
      find.text('Раскладка готова'),
      timeout: const Duration(seconds: 20),
    );
    final sheets = container
        .read(designSessionProvider(designId))
        .value!
        .document
        .spreads
        .length;
    expect(sheets, 4, reason: 'плотная раскладка: 4 листа вместо 10');
    await _screenshotPause(tester, 'smoke-layout');

    await tester.tap(find.text('Проверить'));
    await _pumpUntil(
      tester,
      find.text('В корзину'),
      timeout: const Duration(seconds: 60),
    );
    await _screenshotPause(tester, 'smoke-preflight');

    await tester.tap(find.text('В корзину'));
    await _pumpUntil(
      tester,
      find.text('5,20 BYN'),
      timeout: const Duration(seconds: 60),
    );
    expect(find.text('4 листа'), findsOneWidget);
    expect(find.text('5,20 BYN'), findsNWidgets(2));
    await _screenshotPause(tester, 'smoke-cart');

    await tester.tap(find.text('Оформить'));
    await _pumpUntil(tester, find.text('Самовывоз'));
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('PicPac на Минском').first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.scrollUntilVisible(
      find.byKey(const Key('checkout-name')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const Key('checkout-name')),
      'Тестовый клиент',
    );
    await tester.enterText(
      find.byKey(const Key('checkout-phone')),
      '+375 29 123 45 67',
    );
    await tester.pump();
    await tester.tap(find.text('Оформить заказ'));
    await _pumpUntil(
      tester,
      find.textContaining('Заказ PP-'),
      timeout: const Duration(seconds: 60),
    );
    final orders = await api.orders();
    expect(orders.isOk, isTrue, reason: '${orders.failureOrNull}');
    expect(orders.requireValue.orders, hasLength(1));
    expect(orders.requireValue.orders.single.totals.subtotal.amountMinor, 520);
    await _screenshotPause(tester, 'smoke-order');

    expect(container.read(designSessionProvider(designId)).value, isNotNull);

    if (await directory.exists()) await directory.delete(recursive: true);
    // ignore: avoid_print
    print(
      'SMOKE OK: $sheets листа, 5,20 BYN, заказ ${orders.requireValue.orders.single.number}',
    );
  });
}

Future<List<File>> _fixtures(Directory directory) async {
  final files = <File>[];
  for (final name in const <String>[
    'portrait_orientation6.heic',
    'gradient_640x480.heic',
    'with_gps.heic',
  ]) {
    final file = File('${directory.path}/$name');
    await file.writeAsBytes(fixtureBytes('heic/$name'), flush: true);
    files.add(file);
  }
  for (var index = 0; index < 7; index++) {
    files.add(
      await _writePng(directory, 'generated_$index.png', tint: 20 + index * 12),
    );
  }
  return files;
}

Future<File> _writePng(
  Directory directory,
  String name, {
  required int tint,
}) async {
  const width = 1600;
  const height = 1200;
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

final class _FixturePicker implements PhotoPickerPort {
  _FixturePicker(this._files);

  final List<File> _files;

  @override
  Future<Result<List<PickedFile>>> pickImages({int? limit}) async {
    final picked = <PickedFile>[];
    for (final file in _files) {
      if (limit != null && picked.length >= limit) break;
      final name = file.uri.pathSegments.last;
      picked.add(
        PickedFile(
          path: file.path,
          name: name,
          mimeType: name.endsWith('.heic')
              ? 'image/heic'
              : name.endsWith('.png')
              ? 'image/png'
              : 'image/jpeg',
          bytes: await file.length(),
        ),
      );
    }
    return Ok<List<PickedFile>>(picked);
  }

  @override
  Future<Result<List<PickedFile>>> recoverLostSelection() async =>
      const Ok<List<PickedFile>>(<PickedFile>[]);
}

Future<void> _screenshotPause(WidgetTester tester, String name) async {
  // ignore: avoid_print
  print('PICSCREEN:$name');
  for (var i = 0; i < 50; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _pumpUntilTrue(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 30),
  String what = 'condition',
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (condition()) return;
  }
  fail('timed out waiting for $what');
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('timed out waiting for $finder');
}
