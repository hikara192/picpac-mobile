import 'package:api_contract/api_contract.dart';
import 'package:mock_server/mock_server.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  late MockApi api;
  late String customerToken;
  late String supportToken;
  late Map<String, Object?> order;

  setUp(() async {
    api = MockApi();
    customerToken = await api.login();
    supportToken = await api.loginSupport();
    order = await api.placeOrder(customerToken);
  });

  group('registration', () {
    test('every control is 404 when MOCK_CONTROLS=0', () async {
      final hardened = MockApi(mockControls: false);
      final token = await hardened.login();
      final created = await hardened.placeOrder(token);

      final paths = <(String, String)>[
        ('POST', '/v1/mock/reset'),
        ('POST', '/v1/mock/faults'),
        ('DELETE', '/v1/mock/faults'),
        ('POST', '/v1/mock/auth/challenge'),
        ('POST', '/v1/mock/psp/simulate'),
        ('POST', '/v1/mock/orders/${created['id']}/advance'),
      ];
      for (final (method, path) in paths) {
        final response = await hardened.call(
          method,
          path,
          token: token,
          body: <String, Object?>{},
        );
        expectError(response, 404, ApiErrorCode.notFound);
      }

      expect((await hardened.call('GET', '/health')).status, 200);
      expect((await hardened.call('GET', '/v1/catalog')).status, 200);
    });
  });

  group('role guard', () {
    test('reset and faults demand an authenticated support agent', () async {
      final anonymous = await api.call('POST', '/v1/mock/reset');
      expectError(anonymous, 401, ApiErrorCode.unauthorized);

      final asCustomer = await api.call(
        'POST',
        '/v1/mock/reset',
        token: customerToken,
      );
      expectError(asCustomer, 403, ApiErrorCode.forbidden);

      final faults = await api.call(
        'POST',
        '/v1/mock/faults',
        token: customerToken,
        body: <String, Object?>{'mode': 'upload_interrupt'},
      );
      expectError(faults, 403, ApiErrorCode.forbidden);

      final simulate = await api.call(
        'POST',
        '/v1/mock/psp/simulate',
        token: customerToken,
        body: <String, Object?>{
          'scenario': 'card_success',
          'orderId': order['id'],
        },
      );
      expectError(simulate, 403, ApiErrorCode.forbidden);

      final supported = await api.call(
        'POST',
        '/v1/mock/faults',
        token: supportToken,
        body: <String, Object?>{'mode': 'upload_interrupt'},
      );
      expect(supported.status, 200, reason: supported.text);
    });

    test('an unauthorised reset never wipes the audit log', () async {
      final before = api.server.auditLength;
      expect(before, greaterThan(0));

      await api.call('POST', '/v1/mock/reset');
      await api.call('POST', '/v1/mock/reset', token: customerToken);

      expect(api.server.auditLength, before);
      expect(api.server.orders, isNotEmpty);

      final reset = await api.call(
        'POST',
        '/v1/mock/reset',
        token: supportToken,
      );
      expect(reset.status, 200, reason: reset.text);
      expect(api.server.orders, isEmpty);
      expect(api.server.auditLength, 0);
    });

    test('MOCK_ALLOW_ANONYMOUS=1 opens the controls for a test run', () async {
      final open = MockApi(allowAnonymousMockControls: true);
      final response = await open.call('POST', '/v1/mock/reset');
      expect(response.status, 200, reason: response.text);
    });
  });

  group('webhook secret', () {
    test('a configured secret is used and no dev warning is logged', () async {
      final lines = <String>[];
      final server = MockServer(
        clock: FixedClock(DateTime.utc(2026, 11, 11, 9)),
        seeds: Seeds.embedded(),
        webhookSecret: 'a-real-secret',
        logSink: lines.add,
      );
      expect(server.webhookSecret, 'a-real-secret');
      expect(server.webhookSecretIsDev, isFalse);
      expect(lines.join('\n'), isNot(contains('insecure dev secret')));
    });

    test('a missing secret falls back to the dev one and warns', () async {
      final lines = <String>[];
      final server = MockServer(
        clock: FixedClock(DateTime.utc(2026, 11, 11, 9)),
        seeds: Seeds.embedded(),
        webhookSecret: devPspWebhookSecret,
        logSink: lines.add,
      );
      expect(server.webhookSecretIsDev, isTrue);
      expect(lines.join('\n'), contains('insecure dev secret'));
    });

    test('a webhook signed with another secret is rejected', () async {
      final hardened = MockApi(webhookSecret: 'another-secret');
      final token = await hardened.login();
      final created = await hardened.placeOrder(token);
      final intent = await hardened.call(
        'POST',
        '/v1/orders/${created['id']}/payment-intent',
        token: token,
        headers: <String, String>{'idempotency-key': 'intent-1'},
        body: <String, Object?>{
          'orderId': created['id'],
          'methodId': 'bank_card',
        },
      );
      final rejected = await hardened.webhook('bepaid', <String, Object?>{
        'eventId': 'evt-wrong-secret',
        'intentId': intent.object['id'],
        'type': 'payment.succeeded',
      });
      expectError(rejected, 401, 'invalid_signature');
    });
  });
}
