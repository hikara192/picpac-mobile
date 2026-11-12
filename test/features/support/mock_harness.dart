import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:api_contract/api_contract.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_server/mock_server.dart' as mock;
import 'package:picpac_mobile/app/app.dart';
import 'package:picpac_mobile/app/di.dart';
import 'package:picpac_mobile/app/env.dart';
import 'package:picpac_mobile/app/router.dart';
import 'package:picpac_mobile/core/clock.dart';
import 'package:picpac_mobile/core/media/asset_cache.dart';
import 'package:picpac_mobile/core/orders/demo_controls.dart';
import 'package:picpac_mobile/core/storage/app_database.dart';
import 'package:picpac_mobile/core/storage/draft_store.dart';
import 'package:picpac_mobile/features/_shared/application/design_format.dart';
import 'package:picpac_mobile/network/http_api.dart';
import 'package:picpac_mobile/network/token_store.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:shelf/shelf.dart' as shelf;

import 'design_harness.dart' show writePng;
import 'fixtures.dart';

final class MockCall {
  const MockCall({
    required this.method,
    required this.path,
    required this.status,
    this.idempotencyKey,
    this.body,
  });

  final String method;
  final String path;
  final int status;
  final String? idempotencyKey;
  final String? body;

  bool matches(String method, String path) =>
      this.method == method && this.path == path;

  @override
  String toString() => '$method $path → $status';
}

final class MockBackend {
  MockBackend({DateTime? now, this.mockControls = true}) : now = now ?? testNow;

  final DateTime now;

  final bool mockControls;

  static const String url = 'http://mock.picpac.test';

  late final mock.FixedClock clock = mock.FixedClock(now);

  late final mock.MockServer server = mock.MockServer(
    clock: clock,
    seeds: mock.Seeds.embedded(),
    webhookSecret: 'picpac-test-webhook-secret',
    mockControls: mockControls,
    allowAnonymousMockControls: false,
  );

  late final shelf.Handler handler = mock.createHandler(server);

  final List<MockCall> calls = <MockCall>[];

  bool online = true;

  void restart() {
    server.reset();
    calls.clear();
  }

  List<MockCall> callsTo(String method, String path) => <MockCall>[
    for (final call in calls)
      if (call.matches(method, path)) call,
  ];

  Dio dio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: '$url${ApiPaths.prefix}',
        responseType: ResponseType.json,
        validateStatus: (status) => status != null && status < 400,
      ),
    );
    dio.httpClientAdapter = _InProcessAdapter(this);
    return dio;
  }
}

final class _InProcessAdapter implements HttpClientAdapter {
  _InProcessAdapter(this._backend);

  final MockBackend _backend;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (!_backend.online) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: 'the mock server is not running',
      );
    }
    final bytes = requestStream == null
        ? const <int>[]
        : await requestStream.expand((chunk) => chunk).toList();
    final headers = <String, String>{
      for (final entry in options.headers.entries)
        if (entry.value != null) entry.key.toLowerCase(): '${entry.value}',
      if (options.contentType != null) 'content-type': options.contentType!,
    };
    final response = await _backend.handler(
      shelf.Request(
        options.method,
        options.uri,
        headers: headers,
        body: bytes.isEmpty ? null : bytes,
      ),
    );
    final responseBytes = await response
        .read()
        .expand((chunk) => chunk)
        .toList();
    _backend.calls.add(
      MockCall(
        method: options.method,
        path: options.uri.path,
        status: response.statusCode,
        idempotencyKey:
            headers['idempotency-key'] ??
            headers['Idempotency-Key'.toLowerCase()],
        body: bytes.isEmpty ? null : utf8.decode(bytes, allowMalformed: true),
      ),
    );
    return ResponseBody.fromBytes(
      responseBytes,
      response.statusCode,
      headers: <String, List<String>>{
        for (final entry in response.headers.entries)
          entry.key: <String>[entry.value],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class MockHarness {
  MockHarness._({
    required this.backend,
    required this.tokens,
    required this.database,
    required this.env,
    required this.clock,
    required this.api,
    required this.demoControls,
    required this.draftRoot,
    required this.drafts,
    this.extraOverrides = const <Override>[],
  });

  static Future<MockHarness> create({
    UserRole role = UserRole.customer,
    MockBackend? backend,
    List<Override> extraOverrides = const <Override>[],
  }) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final resolved = backend ?? MockBackend();
    final tokens = TokenStore(InMemorySecureStore());
    final database = AppDatabase(NativeDatabase.memory());
    final root = Directory.systemTemp.createTempSync('picpac_mock_');
    final harness = MockHarness._(
      backend: resolved,
      tokens: tokens,
      database: database,
      env: const AppEnv(apiMode: ApiMode.embedded, flavor: AppFlavor.dev),
      clock: FixedClock(resolved.now),
      api: HttpApi(
        baseUrl: MockBackend.url,
        tokens: tokens,
        dio: resolved.dio(),
      ),
      demoControls: HttpDemoOrderControls(
        baseUrl: MockBackend.url,
        tokens: tokens,
        dio: resolved.dio(),
      ),
      draftRoot: root,
      drafts: DraftStore(
        database: database,
        rootDirectory: () async => root,
        debounce: const Duration(milliseconds: 100),
      ),
      extraOverrides: extraOverrides,
    );
    await harness.signIn(role);
    return harness;
  }

  static Future<MockHarness> forWidgetTest(
    WidgetTester tester, {
    UserRole role = UserRole.customer,
    MockBackend? backend,
    List<Override> extraOverrides = const <Override>[],
  }) async {
    final harness = await tester.runAsync(
      () =>
          create(role: role, backend: backend, extraOverrides: extraOverrides),
    );
    return harness!;
  }

  Future<void> disposeForTest(WidgetTester tester) async {
    await tester.runAsync(dispose);
  }

  Future<T> setup<T>(WidgetTester tester, Future<T> Function() action) async {
    final value = await tester.runAsync(action);
    return value as T;
  }

  final MockBackend backend;
  final TokenStore tokens;
  final AppDatabase database;
  final AppEnv env;
  final FixedClock clock;
  final HttpApi api;
  final HttpDemoOrderControls demoControls;
  final Directory draftRoot;
  final DraftStore drafts;
  final List<Override> extraOverrides;

  late ProviderContainer container;

  Future<void> signIn(UserRole role) async {
    final Result<AuthSession> result;
    switch (role) {
      case UserRole.customer:
        result = await api.login(
          const LoginRequest(
            email: 'customer@picpac.test',
            password: 'Test1234',
          ),
        );
      case UserRole.supportAgent:
        result = await api.login(
          const LoginRequest(
            email: 'support@picpac.test',
            password: 'Test1234',
          ),
        );
      case UserRole.guest:
        result = await api.createAnonymousSession(
          const AnonymousSessionRequest(locale: 'ru'),
        );
      case UserRole.unknown:
        await tokens.clear();
        return;
    }
    expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
  }

  Future<void> signOut() => tokens.clear();

  List<Override> get overrides => <Override>[
    ...appOverrides(
      env: env,
      api: api,
      tokens: tokens,
      database: database,
      clock: clock,
    ),
    draftStoreProvider.overrideWithValue(drafts),
    draftRootProvider.overrideWithValue(() async => draftRoot),
    demoOrderControlsProvider.overrideWithValue(demoControls),
    ...extraOverrides,
  ];

  Future<void> pump(
    WidgetTester tester, {
    String location = AppRoutes.catalog,
  }) async {
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
    if (location != AppRoutes.catalog) {
      container.read(routerProvider).go(location);
      await settle(tester);
    }
  }

  void go(String location, {Object? extra}) =>
      container.read(routerProvider).go(location, extra: extra);

  void push(String location, {Object? extra}) =>
      container.read(routerProvider).push(location, extra: extra);

  Future<void> settle(WidgetTester tester, {int frames = 8}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> settleReal(WidgetTester tester, {int frames = 20}) async {
    for (var i = 0; i < frames; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<DesignDto> seedProject(
    WidgetTester tester, {
    int photos = 10,
    int width = 800,
    int height = 1200,
  }) async {
    final prepared = await tester.runAsync(() async {
      final assets = <PhotoAsset>[];
      final files = <File>[];
      for (var index = 0; index < photos; index++) {
        final file = await writePng(
          draftRoot,
          'seed_${DateTime.now().microsecondsSinceEpoch}_$index.png',
          width: width,
          height: height,
          color: Color(0xFF335577 + index * 0x0A0A0A),
        );
        final digest = sha256.convert(await file.readAsBytes()).toString();
        files.add(file);
        assets.add(
          PhotoAsset(
            id: 'photo_${digest.substring(0, 8)}',
            sha256: digest,
            widthPx: width,
            heightPx: height,
            mimeType: 'image/png',
            bytes: await file.length(),
          ),
        );
      }
      return (assets: assets, files: files);
    });
    final assets = prepared!.assets;
    final document = DesignDocument(
      product: const DocumentProduct(id: 'photo_print', formatId: '10x15'),
      spreads: <Spread>[
        for (var index = 0; index < assets.length; index++)
          Spread(
            id: 'sheet_${index + 1}',
            templateId: 'single_10x15',
            background: SpreadBackground.color('#FAF5ED'),
            slots: <Slot>[Slot(id: 'main', photoId: assets[index].id)],
          ),
      ],
      spreadsCount: assets.length,
      assets: assets,
    );
    final created = await tester.runAsync(() => api.createDesign(document));
    final design = created!.requireValue;
    await tester.runAsync(() async {
      final cache = DesignAssetCache(rootDirectory: () async => draftRoot);
      for (var index = 0; index < assets.length; index++) {
        await cache.store(
          designId: design.id,
          sha256: assets[index].sha256,
          source: prepared.files[index],
        );
      }
      await drafts.saveNow(
        design.document,
        designId: design.id,
        productId: design.document.product.id,
      );
    });
    return design;
  }

  Future<String> seedLocalDraft(WidgetTester tester, {int photos = 0}) async {
    const designId = 'local_test';
    final document = DesignDocument(
      product: const DocumentProduct(id: 'photo_print', formatId: '10x15'),
      assets: <PhotoAsset>[
        for (var index = 0; index < photos; index++)
          PhotoAsset(
            id: 'photo_$index',
            sha256: '$index'.padLeft(64, 'a'),
            widthPx: 1600,
            heightPx: 2400,
            mimeType: 'image/png',
            bytes: 1024,
          ),
      ],
    );
    await tester.runAsync(
      () => drafts.saveNow(
        document,
        designId: designId,
        productId: document.product.id,
      ),
    );
    return designId;
  }

  Future<DesignDto> createPrintDesign({int sheets = 2}) async {
    final document = DesignDocument(
      product: const DocumentProduct(id: 'photo_print', formatId: '10x15'),
      spreads: <Spread>[
        for (var index = 0; index < sheets; index++)
          Spread(
            id: 'sheet_${index + 1}',
            templateId: 'single_10x15',
            background: SpreadBackground.color('#FAF5ED'),
            slots: <Slot>[Slot(id: 'main', photoId: 'photo_1')],
          ),
      ],
      spreadsCount: sheets,
      assets: <PhotoAsset>[
        PhotoAsset(
          id: 'photo_1',
          sha256: 'a' * 64,
          widthPx: 1600,
          heightPx: 2400,
          mimeType: 'image/jpeg',
          bytes: 220000,
        ),
      ],
    );
    final created = await api.createDesign(document);
    expect(created.isOk, isTrue, reason: '${created.failureOrNull}');
    return created.requireValue;
  }

  Future<DesignDto> createBookDesign({int spreads = 10}) async {
    final document = DesignDocument(
      product: const DocumentProduct(
        id: 'photo_book_classic',
        formatId: '20x20',
      ),
      spreads: <Spread>[
        for (var index = 0; index < spreads; index++)
          Spread(
            id: 'sheet_${index + 1}',
            templateId: 'spread_full',
            background: SpreadBackground.color('#FAF5ED'),
            slots: <Slot>[Slot(id: 'main', photoId: 'photo_1')],
          ),
      ],
      spreadsCount: spreads,
      assets: <PhotoAsset>[
        PhotoAsset(
          id: 'photo_1',
          sha256: 'b' * 64,
          widthPx: 2400,
          heightPx: 1200,
          mimeType: 'image/jpeg',
          bytes: 220000,
        ),
      ],
    );
    final created = await api.createDesign(document);
    expect(created.isOk, isTrue, reason: '${created.failureOrNull}');
    return created.requireValue;
  }

  Future<Cart> addToCart(String designId, {int quantity = 1}) async {
    final added = await api.addCartItem(
      AddCartItemRequest(designId: designId, quantity: quantity),
    );
    expect(added.isOk, isTrue, reason: '${added.failureOrNull}');
    return added.requireValue;
  }

  Future<Order> placeOrder({
    int sheets = 2,
    String idempotencyKey = 'order-key',
  }) async {
    final design = await createPrintDesign(sheets: sheets);
    final cart = await addToCart(design.id, quantity: sheets);
    final points = await api.pickupPoints();
    final point = points.requireValue.first;
    final slot = point.slots.firstWhere((candidate) => candidate.available);
    final order = await api.checkout(
      CheckoutRequest(
        cartId: cart.id,
        delivery: DeliverySelection(
          kind: DeliveryKind.pickup,
          optionId: 'pickup_main',
          pointId: point.id,
          slot: slot.start,
        ),
        contact: const ContactInfo(
          name: 'Тестовый клиент',
          phone: '+375291234567',
        ),
      ),
      idempotencyKey: idempotencyKey,
    );
    expect(order.isOk, isTrue, reason: '${order.failureOrNull}');
    return order.requireValue;
  }

  Future<void> dispose() async {
    await database.close();
    try {
      if (draftRoot.existsSync()) draftRoot.deleteSync(recursive: true);
    } on FileSystemException {
    }
  }
}
