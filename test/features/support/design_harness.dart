import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:api_contract/api_contract.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:picpac_mobile/app/app.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:picpac_mobile/app/di.dart';
import 'package:picpac_mobile/app/env.dart';
import 'package:picpac_mobile/app/router.dart';
import 'package:picpac_mobile/core/analytics.dart';
import 'package:picpac_mobile/core/clock.dart';
import 'package:picpac_mobile/core/media/asset_cache.dart';
import 'package:picpac_mobile/core/media/photo_format.dart';
import 'package:picpac_mobile/core/media/photo_normalizer.dart';
import 'package:picpac_mobile/core/media/photo_picker.dart';
import 'package:picpac_mobile/core/media/photo_storage.dart';
import 'package:picpac_mobile/core/storage/app_database.dart';
import 'package:picpac_mobile/core/storage/draft_store.dart';
import 'package:picpac_mobile/features/_shared/application/design_format.dart';
import 'package:picpac_mobile/features/_shared/application/design_session.dart';
import 'package:picpac_mobile/features/_shared/application/media_providers.dart';
import 'package:picpac_mobile/network/token_store.dart';

import 'design_fixtures.dart';

class FakeApi extends Mock implements ApiPort {}

final class FakePhotoPicker implements PhotoPickerPort {
  FakePhotoPicker();

  List<PickedFile> selection = const <PickedFile>[];

  MediaFailure? failure;

  int calls = 0;

  int? lastLimit;

  void queue(List<PickedFile> files) => selection = files;

  @override
  Future<Result<List<PickedFile>>> pickImages({int? limit}) async {
    calls++;
    lastLimit = limit;
    final error = failure;
    if (error != null) {
      failure = null;
      return Err<List<PickedFile>>(error);
    }
    final files = selection;
    selection = const <PickedFile>[];
    return Ok<List<PickedFile>>(files);
  }

  @override
  Future<Result<List<PickedFile>>> recoverLostSelection() async =>
      const Ok<List<PickedFile>>(<PickedFile>[]);
}

final class FakePhotoStorage implements PhotoStoragePort {
  final List<UploadTicket> uploads = <UploadTicket>[];

  Failure? failure;

  @override
  Future<Result<void>> putObject({
    required UploadTicket ticket,
    required File file,
    void Function(int sent, int total)? onProgress,
  }) async {
    uploads.add(ticket);
    onProgress?.call(1, 1);
    final error = failure;
    if (error != null) {
      failure = null;
      return Err<void>(error);
    }
    return const Ok<void>(null);
  }
}

final class FakePhotoNormalizer implements PhotoNormalizerPort {
  FakePhotoNormalizer({this.outputBytes});

  Uint8List? outputBytes;

  MediaFailure? failure;

  final List<String> calls = <String>[];

  final List<int> maxPixelsSeen = <int>[];

  @override
  Future<Result<NormalizedPhoto>> normalize({
    required File source,
    required File output,
    required String sourceMime,
    required String outputMime,
    int quality = PhotoFormats.jpegQuality,
    int maxPixels = PhotoFormats.maxOutputPixels,
  }) async {
    calls.add(sourceMime);
    maxPixelsSeen.add(maxPixels);
    final error = failure;
    if (error != null) {
      failure = null;
      return Err<NormalizedPhoto>(error);
    }
    final bytes = outputBytes ?? await defaultJpegBytes();
    await output.writeAsBytes(bytes, flush: true);
    final size = imageSizeOf(bytes);
    return Ok<NormalizedPhoto>(
      NormalizedPhoto(
        file: output,
        mimeType: outputMime,
        sourceMime: sourceMime,
        widthPx: size.$1,
        heightPx: size.$2,
        bytes: bytes.length,
        sha256: sha256.convert(bytes).toString(),
        converted: true,
      ),
    );
  }

  static Uint8List? _jpegCache;

  static Future<Uint8List> defaultJpegBytes() async {
    return _jpegCache ??= await File('test/fixtures/jpeg/gradient_320x240.jpg')
        .readAsBytes();
  }
}

(int, int) imageSizeOf(Uint8List bytes) {
  if (bytes.length > 24) {
    if (bytes[0] == 0x89 && bytes[1] == 0x50) {
      final data = ByteData.sublistView(bytes);
      return (data.getUint32(16), data.getUint32(20));
    }
  }
  var offset = 2;
  while (offset + 9 < bytes.length) {
    if (bytes[offset] != 0xFF) {
      offset++;
      continue;
    }
    final marker = bytes[offset + 1];
    final length = (bytes[offset + 2] << 8) | bytes[offset + 3];
    final isSof =
        marker >= 0xC0 &&
        marker <= 0xCF &&
        marker != 0xC4 &&
        marker != 0xC8 &&
        marker != 0xCC;
    if (isSof) {
      final height = (bytes[offset + 5] << 8) | bytes[offset + 6];
      final width = (bytes[offset + 7] << 8) | bytes[offset + 8];
      return (width, height);
    }
    offset += 2 + length;
  }
  return (0, 0);
}

final class SpyAnalytics implements Analytics {
  final List<AnalyticsEvent> events = <AnalyticsEvent>[];
  final List<Map<String, Object?>> payloads = <Map<String, Object?>>[];

  @override
  void track(
    AnalyticsEvent event, [
    Map<String, Object?> attributes = const <String, Object?>{},
  ]) {
    events.add(event);
    payloads.add(attributes);
  }

  bool has(AnalyticsEvent event) => events.contains(event);
}

final class DesignHarness {
  DesignHarness._({
    required this.root,
    required this.database,
    required this.tokens,
    required this.env,
    required this.clock,
    required this.api,
    required this.picker,
    required this.storage,
    required this.normalizer,
    required this.analytics,
    required this.drafts,
    required this.format,
    this.extraOverrides = const <Override>[],
  });

  static Future<DesignHarness> create({
    UserRole role = UserRole.customer,
    ProductFormat? format,
    Directory? rootDirectory,
    List<Override> extraOverrides = const <Override>[],
  }) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final root =
        rootDirectory ?? await Directory.systemTemp.createTemp('picpac_test_');
    final database = AppDatabase(NativeDatabase.memory());
    final tokens = TokenStore(InMemorySecureStore());
    if (role != UserRole.unknown) {
      await tokens.save(AuthSession(token: 'test-token', role: role));
    }
    final resolvedFormat = format ?? printFormat();
    return DesignHarness._(
      root: root,
      database: database,
      tokens: tokens,
      env: const AppEnv(apiMode: ApiMode.embedded, flavor: AppFlavor.dev),
      clock: FixedClock(DateTime.utc(2026, 11, 11, 12)),
      api: FakeApi(),
      picker: FakePhotoPicker(),
      storage: FakePhotoStorage(),
      normalizer: FakePhotoNormalizer(),
      analytics: SpyAnalytics(),
      drafts: DraftStore(
        database: database,
        rootDirectory: () async => root,
        debounce: const Duration(milliseconds: 100),
      ),
      format: resolvedFormat,
      extraOverrides: extraOverrides,
    );
  }

  final Directory root;

  final AppDatabase database;
  final TokenStore tokens;
  final AppEnv env;
  final FixedClock clock;
  final FakeApi api;
  final FakePhotoPicker picker;
  final FakePhotoStorage storage;
  final FakePhotoNormalizer normalizer;
  final SpyAnalytics analytics;
  final DraftStore drafts;
  final ProductFormat format;

  final List<Override> extraOverrides;

  late ProviderContainer container;

  DesignDocument? lastPut;

  void stubBasics({
    Failure? designFailure,
    Failure? putFailure,
    DesignDto? design,
    bool serverPreflight = true,
  }) {
    final dto = design ?? designDto();
    when(() => api.catalog())
        .thenAnswer((_) async => Ok<CatalogResponse>(catalogWith(format)));
    when(() => api.product(any()))
        .thenAnswer((_) async => Ok<Product>(printProduct(format)));
    when(() => api.design(any())).thenAnswer((_) async {
      final failure = designFailure;
      if (failure != null) return Err<DesignDto>(failure);
      return Ok<DesignDto>(dto);
    });
    when(
      () => api.putDesign(
        any(),
        any(),
        ifMatchRevision: any(named: 'ifMatchRevision'),
      ),
    ).thenAnswer((invocation) async {
      final failure = putFailure;
      if (failure != null) return Err<DesignDto>(failure);
      final putDocument = invocation.positionalArguments[1] as DesignDocument;
      lastPut = putDocument;
      return Ok<DesignDto>(
        DesignDto(
          id: 'dsg_1',
          revision: 2,
          document: putDocument,
          updatedAt: DateTime.utc(2026, 11, 11, 12, 5),
        ),
      );
    });
    when(() => api.preflight(any(), revision: any(named: 'revision')))
        .thenAnswer((invocation) async {
          if (!serverPreflight) {
            return Err<PreflightDto>(ApiFailure.networkUnavailable());
          }
          final report = PreflightProjection.run(
            document: lastPut ?? dto.document,
            spec: format.toPrintSpec(),
            templates: format.templateMap(),
          );
          return Ok<PreflightDto>(preflightDto(report));
        });
    when(() => api.addCartItem(any()))
        .thenAnswer((_) async => Ok<Cart>(cartWith('dsg_1')));
    when(() => api.cart()).thenAnswer((_) async => Ok<Cart>(cartWith('dsg_1')));
    when(() => api.presignUpload(any()))
        .thenAnswer((_) async => Ok<UploadTicket>(uploadTicket()));
    when(
      () => api.completeUpload(
        uploadId: any(named: 'uploadId'),
        sha256: any(named: 'sha256'),
      ),
    ).thenAnswer((invocation) async {
      final sha = invocation.namedArguments[#sha256]! as String;
      return Ok<CompletedUpload>(
        completedUpload(sha256: sha, widthPx: 1200, heightPx: 900),
      );
    });
  }

  List<Override> get overrides => <Override>[
    ...appOverrides(
      env: env,
      api: api,
      tokens: tokens,
      database: database,
      clock: clock,
    ),
    draftStoreProvider.overrideWithValue(drafts),
    draftRootProvider.overrideWithValue(() async => root),
    photoPickerProvider.overrideWithValue(picker),
    photoStorageProvider.overrideWithValue(storage),
    photoNormalizerProvider.overrideWithValue(normalizer),
    analyticsProvider.overrideWithValue(analytics),
    ...extraOverrides,
  ];

  static Future<DesignHarness> forWidgetTest(
    WidgetTester tester, {
    UserRole role = UserRole.customer,
    ProductFormat? format,
    Directory? rootDirectory,
    List<Override> extraOverrides = const <Override>[],
  }) async {
    final harness = await tester.runAsync(
      () => create(
        role: role,
        format: format,
        rootDirectory: rootDirectory,
        extraOverrides: extraOverrides,
      ),
    );
    return harness!;
  }

  Future<DesignDocument> seedPhotosForTest(
    WidgetTester tester, {
    int count = 3,
    String designId = 'dsg_1',
    int width = 1200,
    int height = 900,
  }) async {
    final document = await tester.runAsync(
      () => seedPhotos(
        count: count,
        designId: designId,
        width: width,
        height: height,
      ),
    );
    return document!;
  }

  Future<void> settleReal(WidgetTester tester, {int frames = 20}) async {
    for (var i = 0; i < frames; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  ProviderContainer mount() {
    container = ProviderContainer(overrides: overrides);
    return container;
  }

  Future<void> pump(
    WidgetTester tester, {
    String location = '/create/dsg_1',
    Object? extra,
  }) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: PicPacApp(env: env),
      ),
    );
    await settle(tester);
    container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    container.read(routerProvider).go(location, extra: extra);
    await settleReal(tester, frames: 16);
  }

  DesignSessionState? get session =>
      container.read(designSessionProvider('dsg_1')).value;

  Future<void> settle(WidgetTester tester, {int frames = 6}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<DesignDocument> seedPhotos({
    int count = 3,
    String designId = 'dsg_1',
    int width = 1200,
    int height = 900,
  }) async {
    final cache = DesignAssetCache(rootDirectory: () async => root);
    final assets = <PhotoAsset>[];
    for (var i = 0; i < count; i++) {
      final file = await writePng(
        root,
        'seed_${DateTime.now().microsecondsSinceEpoch}_$i.png',
        width: width + i,
        height: height,
        color: Color(0xFF335577 + i * 0x0A0A0A),
      );
      final digest = sha256.convert(await file.readAsBytes()).toString();
      await cache.store(designId: designId, sha256: digest, source: file);
      assets.add(
        PhotoAsset(
          id: 'photo_${digest.substring(0, 12)}',
          sha256: digest,
          widthPx: width + i,
          heightPx: height,
          mimeType: 'image/png',
          bytes: await file.length(),
        ),
      );
    }
    final format = this.format;
    final template = format.templates.first.toPrintTemplate();
    return AutoLayoutSheets(template: template).applyCore(
      DesignDocument(
        product: DocumentProduct(id: 'photo_print', formatId: format.id),
        assets: assets,
      ),
    );
  }

  Future<void> waitForSync(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(seconds: 3));
    await settle(tester, frames: 6);
  }

  Future<void> disposeForTest(WidgetTester tester) async {
    await tester.runAsync(dispose);
  }

  Future<void> dispose() async {
    await database.close();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        if (await root.exists()) await root.delete(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    }
  }
}

Future<File> writePng(
  Directory directory,
  String name, {
  int width = 1200,
  int height = 900,
  Color color = const Color(0xFF88AA77),
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  final file = File('${directory.path}/$name');
  await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
  return file;
}

PickedFile pickedPng(File file, {String? mimeType = PhotoFormats.png}) =>
    PickedFile(
      path: file.path,
      name: file.uri.pathSegments.last,
      mimeType: mimeType,
      bytes: file.lengthSync(),
    );

void registerDesignFallbacks() {
  registerFallbackValue(
    const PresignUploadRequest(
      fileName: 'a.png',
      mimeType: 'image/png',
      bytes: 1,
      sha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    ),
  );
  registerFallbackValue(const AddCartItemRequest(designId: 'dsg_1'));
  registerFallbackValue(
    DesignDocument.start(
      product: const DocumentProduct(id: 'photo_print', formatId: '10x15'),
    ),
  );
  registerFallbackValue(uploadTicket());
}
