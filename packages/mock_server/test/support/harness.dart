import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:mock_server/mock_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

const String testWebhookSecret = 'picpac-test-webhook-secret';

final class MockApi {
  MockApi._(this.clock, this.server) {
    handler = createHandler(server);
  }

  factory MockApi({
    DateTime? now,
    String webhookSecret = testWebhookSecret,
    bool mockControls = true,
    bool allowAnonymousMockControls = false,
  }) {
    final clock = FixedClock(now ?? DateTime.utc(2026, 11, 11, 9));
    return MockApi._(
      clock,
      MockServer(
        clock: clock,
        seeds: Seeds.embedded(),
        webhookSecret: webhookSecret,
        mockControls: mockControls,
        allowAnonymousMockControls: allowAnonymousMockControls,
      ),
    );
  }

  final FixedClock clock;
  final MockServer server;
  late final Handler handler;

  Future<MockResponse> call(
    String method,
    String path, {
    Object? body,
    Map<String, String> headers = const <String, String>{},
    String? token,
  }) async {
    final requestHeaders = <String, String>{...headers};
    if (token != null) requestHeaders['authorization'] = 'Bearer $token';
    final payload = switch (body) {
      null => null,
      final String text => text,
      final List<int> data => data,
      _ => jsonEncode(body),
    };
    if (payload != null && !requestHeaders.containsKey('content-type')) {
      requestHeaders['content-type'] = 'application/json';
    }
    final response = await handler(
      Request(
        method,
        Uri.parse('http://mock.local$path'),
        body: payload,
        headers: requestHeaders,
      ),
    );
    return MockResponse(
      status: response.statusCode,
      headers: response.headers,
      text: await response.readAsString(),
    );
  }


  Future<String> anonymous() async {
    final response = await call(
      'POST',
      '/v1/auth/anonymous',
      body: <String, Object?>{'locale': 'ru'},
    );
    expect(response.status, 200, reason: response.text);
    return response.object['token']! as String;
  }

  Future<String> login([String email = 'customer@picpac.test']) async {
    final response = await call(
      'POST',
      '/v1/auth/login',
      body: <String, Object?>{'email': email, 'password': 'Test1234'},
    );
    expect(response.status, 200, reason: response.text);
    return response.object['token']! as String;
  }

  Future<String> loginSupport() => login('support@picpac.test');

  Future<MockResponse> webhook(
    String provider,
    Map<String, Object?> event, {
    String? timestamp,
    String? signature,
  }) {
    final stamp = timestamp ?? clock.now().toUtc().toIso8601String();
    final payload = jsonEncode(event);
    final mac =
        signature ??
        pspWebhookSignature(
          secret: testWebhookSecret,
          timestamp: stamp,
          body: utf8.encode(payload),
        );
    return call(
      'POST',
      '/v1/webhooks/psp/$provider',
      body: payload,
      headers: <String, String>{
        'x-psp-timestamp': stamp,
        'x-psp-signature': mac,
      },
    );
  }

  String registerCustomer(String id, {String? name}) {
    final customer = CustomerRecord(
      id: id,
      createdAt: clock.now(),
      role: UserRole.customer,
      isGuest: false,
      name: name ?? id,
    );
    server.customers[id] = customer;
    return server.issueSession(customer).token;
  }


  Future<Map<String, Object?>> createPrintDesign(
    String token, {
    int quantity = 1,
    String formatId = '10x15',
  }) async {
    final response = await call(
      'POST',
      '/v1/designs',
      body: printDesignJson(formatId: formatId),
      token: token,
    );
    expect(response.status, 201, reason: response.text);
    return response.object;
  }

  Future<MockResponse> price({
    int spreadsCount = 1,
    String? promoCode,
    Map<String, Object?>? delivery,
  }) => call(
    'POST',
    '/v1/price',
    body: <String, Object?>{
      'productId': 'photo_print',
      'formatId': '10x15',
      'options': <String, String>{},
      'spreadsCount': spreadsCount,
      'promoCode': ?promoCode,
      'delivery': ?delivery,
    },
  );


  Future<Map<String, Object?>> addToCart(
    String token,
    String designId, {
    int quantity = 1,
  }) async {
    final response = await call(
      'POST',
      '/v1/cart/items',
      body: <String, Object?>{'designId': designId, 'quantity': quantity},
      token: token,
    );
    expect(response.status, 200, reason: response.text);
    return response.object;
  }


  Future<Map<String, Object?>> pickupSelection() async {
    final response = await call('GET', '/v1/pickup/points');
    expect(response.status, 200, reason: response.text);
    final point = response.list.first! as Map<String, Object?>;
    final slots = (point['slots']! as List).cast<Map<String, Object?>>();
    final available = slots.firstWhere(
      (slot) => slot['available'] == true,
      orElse: () => throw StateError('no available pickup slot'),
    );
    return <String, Object?>{
      'kind': 'pickup',
      'optionId': 'pickup_main',
      'pointId': point['id'],
      'slot': available['start'],
    };
  }

  Future<MockResponse> checkout(
    String token, {
    required String cartId,
    String idempotencyKey = 'checkout-key-1',
    String? promoCode,
    Map<String, Object?>? delivery,
  }) async {
    final selection = delivery ?? await pickupSelection();
    return call(
      'POST',
      '/v1/checkout',
      token: token,
      headers: <String, String>{'idempotency-key': idempotencyKey},
      body: <String, Object?>{
        'cartId': cartId,
        'delivery': selection,
        'contact': <String, Object?>{
          'name': 'Тестовый клиент',
          'phone': '+375 29 123-45-67',
          'email': 'customer@picpac.test',
        },
        'promoCode': ?promoCode,
      },
    );
  }

  Future<Map<String, Object?>> placeOrder(
    String token, {
    int quantity = 10,
    String idempotencyKey = 'order-key-1',
    String? promoCode,
  }) async {
    final design = await createPrintDesign(token, quantity: quantity);
    final cart = await addToCart(
      token,
      design['id']! as String,
      quantity: quantity,
    );
    final response = await checkout(
      token,
      cartId: cart['id']! as String,
      idempotencyKey: idempotencyKey,
      promoCode: promoCode,
    );
    expect(response.status, 201, reason: response.text);
    return response.object;
  }

  Future<MockResponse> directOrder(
    String token,
    String designId, {
    int quantity = 1,
    String idempotencyKey = 'direct-key-1',
    Map<String, Object?>? delivery,
  }) async {
    final selection = delivery ?? await pickupSelection();
    return call(
      'POST',
      '/v1/orders',
      token: token,
      headers: <String, String>{'idempotency-key': idempotencyKey},
      body: <String, Object?>{
        'lines': <Object?>[
          <String, Object?>{'designId': designId, 'quantity': quantity},
        ],
        'delivery': selection,
        'contact': <String, Object?>{
          'name': 'Тестовый клиент',
          'phone': '+375291234567',
        },
      },
    );
  }
}

final class MockResponse {
  MockResponse({
    required this.status,
    required this.headers,
    required this.text,
  });

  final int status;
  final Map<String, String> headers;
  final String text;

  Object? get json => text.isEmpty ? null : jsonDecode(text);

  Map<String, Object?> get object => (json! as Map).cast<String, Object?>();

  List<Object?> get list => (json! as List).cast<Object?>();

  String? header(String name) => headers[name.toLowerCase()] ?? headers[name];

  @override
  String toString() => 'MockResponse($status): $text';
}

Map<String, Object?> printDesignJson({String formatId = '10x15'}) {
  final asset = PhotoAsset(
    id: 'p1',
    sha256: List<String>.filled(64, 'a').join(),
    widthPx: 3000,
    heightPx: 2000,
    mimeType: 'image/jpeg',
    bytes: 1024 * 1024,
  );
  return DesignDocument(
    product: DocumentProduct(id: 'photo_print', formatId: formatId),
    spreads: <Spread>[
      Spread(
        id: 's1',
        templateId: formatId == '10x15' ? 'single_10x15' : 'single_sheet',
        background: SpreadBackground.color('#FFFFFF'),
        slots: <Slot>[Slot(id: 'main', photoId: asset.id)],
      ),
    ],
    spreadsCount: 1,
    assets: <PhotoAsset>[asset],
  ).toJson();
}

Map<String, Object?> emptySlotDesignJson() {
  final asset = PhotoAsset(
    id: 'p1',
    sha256: List<String>.filled(64, 'b').join(),
    widthPx: 3000,
    heightPx: 2000,
    mimeType: 'image/jpeg',
    bytes: 1024 * 1024,
  );
  return DesignDocument(
    product: const DocumentProduct(id: 'photo_print', formatId: '10x15'),
    spreads: <Spread>[
      Spread(
        id: 's1',
        templateId: 'duo_10x15',
        background: SpreadBackground.color('#FFFFFF'),
        slots: <Slot>[
          Slot(id: 'top', photoId: asset.id),
          const Slot(id: 'bottom'),
        ],
      ),
    ],
    spreadsCount: 1,
    assets: <PhotoAsset>[asset],
  ).toJson();
}

Map<String, String> fieldErrors(MockResponse response) {
  final raw = response.object['fieldErrors'];
  if (raw is! Map) return const <String, String>{};
  return <String, String>{
    for (final entry in raw.entries)
      if (entry.key is String && entry.value is String)
        entry.key! as String: entry.value! as String,
  };
}

void expectError(MockResponse response, int status, String code) {
  expect(response.status, status, reason: response.text);
  expect(response.object['code'], code, reason: response.text);
  expect(response.object['requestId'], isA<String>());
  expect(response.object['statusCode'], status);
}
