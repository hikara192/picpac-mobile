import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  late MockApi api;
  late String token;
  late Map<String, Object?> order;

  setUp(() async {
    api = MockApi();
    token = await api.login();
    order = await api.placeOrder(token);
  });

  Future<MockResponse> lookup(
    String number,
    String last4, {
    String? as,
    String? ip,
  }) => api.call(
    'POST',
    '/v1/orders/lookup',
    token: as,
    headers: <String, String>{'x-forwarded-for': ?ip},
    body: <String, Object?>{'number': number, 'phoneLast4': last4},
  );

  group('guest order lookup', () {
    test('returns a reduced card for the number and the last digits', () async {
      final response = await lookup(order['number']! as String, '4567');
      expect(response.status, 200, reason: response.text);
      final parsed = Order.fromJson(response.object);
      expect(parsed.number, order['number']);
      expect(parsed.items, isEmpty);
      expect(parsed.delivery.address, isNull);
      expect(parsed.delivery.pickupCode, isNull);
      expect(parsed.delivery.slot, isNull);
      expect(parsed.delivery.trackingNumber, isNull);
      expect(parsed.totals.total.amountMinor, 1300);
      expect(response.text, isNot(contains('pickupCode')));
      expect(response.text, isNot(contains('"items":[{')));

      final owned = await api.call(
        'GET',
        '/v1/orders/${order['id']}',
        token: token,
      );
      expect(Order.fromJson(owned.object).items, isNotEmpty);
    });

    test('answers identically for a wrong number and a wrong phone', () async {
      final wrongNumber = await lookup('PP-9999', '4567');
      final wrongPhone = await lookup(order['number']! as String, '0000');
      expectError(wrongNumber, 404, ApiErrorCode.notFound);
      expectError(wrongPhone, 404, ApiErrorCode.notFound);
      expect(wrongNumber.object['code'], wrongPhone.object['code']);
      expect(wrongNumber.object['message'], wrongPhone.object['message']);
      expect(wrongNumber.object['message'], 'order not found');
    });

    test('five failed guesses lock the number for every session', () async {
      final number = order['number']! as String;
      for (var i = 0; i < 4; i++) {
        final attempt = await lookup(number, '0000');
        expectError(attempt, 404, ApiErrorCode.notFound);
      }
      final correct = await lookup(number, '4567');
      expect(correct.status, 200, reason: correct.text);

      for (var i = 0; i < 5; i++) {
        expectError(await lookup(number, '0000'), 404, ApiErrorCode.notFound);
      }
      final limited = await lookup(number, '0000');
      expectError(limited, 429, ApiErrorCode.rateLimited);
      expect(limited.object['retryAfterSeconds'], isA<int>());
      expect(limited.object['retryAfterSeconds'], greaterThan(0));
      expect(limited.header('retry-after'), isNotNull);

      final fresh = await api.anonymous();
      final withFreshSession = await lookup(number, '0000', as: fresh);
      expectError(withFreshSession, 429, ApiErrorCode.rateLimited);

      final otherIp = await lookup(number, '0000', ip: '203.0.113.7');
      expectError(otherIp, 404, ApiErrorCode.notFound);

      final correctWhileLocked = await lookup(number, '4567');
      expectError(correctWhileLocked, 429, ApiErrorCode.rateLimited);

      api.clock.advance(const Duration(minutes: 15, seconds: 1));
      final recovered = await lookup(number, '4567');
      expect(recovered.status, 200, reason: recovered.text);
    });

    test('the lock doubles after a second round of failures', () async {
      final number = order['number']! as String;
      for (var i = 0; i < 5; i++) {
        await lookup(number, '0000');
      }
      api.clock.advance(const Duration(minutes: 15, seconds: 1));
      expectError(await lookup(number, '0000'), 404, ApiErrorCode.notFound);
      for (var i = 0; i < 4; i++) {
        await lookup(number, '0000');
      }
      final limited = await lookup(number, '0000');
      expectError(limited, 429, ApiErrorCode.rateLimited);
      expect(
        limited.object['retryAfterSeconds'],
        greaterThan(15 * 60),
        reason: 'the second block is longer than the first',
      );

      api.clock.advance(const Duration(minutes: 15, seconds: 1));
      expectError(await lookup(number, '0000'), 429, ApiErrorCode.rateLimited);
    });

    test('every lookup is audited without PII', () async {
      await lookup('PP-9999', '4567');
      final response = await lookup(order['number']! as String, '4567');
      expect(response.status, 200);

      final audit = await api.call(
        'GET',
        '/v1/audit?limit=100',
        token: await api.loginSupport(),
      );
      final records = <AuditRecord>[
        for (final raw in audit.list)
          AuditRecord.fromJson((raw! as Map).cast<String, Object?>()),
      ];
      final lookups = records
          .where((record) => record.action == 'order.lookup')
          .toList();
      expect(lookups, hasLength(2));
      expect(lookups.map((record) => record.result), contains('denied'));
      expect(lookups.map((record) => record.result), contains('success'));
      for (final record in lookups) {
        expect(record.details.values.join(), isNot(contains('4567')));
        expect(
          record.details.values.join(),
          isNot(contains(order['number']! as String)),
        );
      }
    });
  });

  group('claiming an order', () {
    String guestOwnedOrder() {
      final guest = api.server.createGuest();
      final record = api.server.orders[order['id']! as String]!;
      record.accessIds.clear();
      record.ownerId = guest.id;
      return guest.id;
    }

    test('a known phone cannot take over a customer order', () async {
      final other = api.registerCustomer('cus_other');
      final design = await api.call(
        'POST',
        '/v1/designs',
        token: other,
        body: printDesignJson(),
      );
      final otherOrder = await api.directOrder(
        other,
        design.object['id']! as String,
      );
      final orderId = otherOrder.object['id']! as String;

      final denied = await api.call(
        'POST',
        '/v1/orders/$orderId/claim',
        token: token,
        headers: <String, String>{'idempotency-key': 'claim-1'},
        body: <String, Object?>{'phoneLast4': '4567'},
      );
      expectError(denied, 409, 'order_already_claimed');
      expect(api.server.orders[orderId]!.ownerId, 'cus_other');
    });

    test('three failed claims lock the number', () async {
      final guestId = guestOwnedOrder();
      final orderId = order['id']! as String;
      final number = order['number']! as String;

      for (var i = 0; i < 3; i++) {
        final denied = await api.call(
          'POST',
          '/v1/orders/$orderId/claim',
          token: token,
          headers: <String, String>{'idempotency-key': 'claim-fail-$i'},
          body: <String, Object?>{'phoneLast4': '0000'},
        );
        expectError(denied, 403, ApiErrorCode.forbidden);
      }
      final limited = await api.call(
        'POST',
        '/v1/orders/$orderId/claim',
        token: token,
        headers: <String, String>{'idempotency-key': 'claim-locked'},
        body: <String, Object?>{'phoneLast4': '4567'},
      );
      expectError(limited, 429, ApiErrorCode.rateLimited);
      expect(limited.object['retryAfterSeconds'], isA<int>());
      expect(api.server.orders[orderId]!.ownerId, guestId);
      expect(number, api.server.orders[orderId]!.number);
    });

    test('claiming keeps the guest owner in the history', () async {
      final guestId = guestOwnedOrder();
      final orderId = order['id']! as String;
      final guestToken = api.server
          .issueSession(api.server.customers[guestId]!)
          .token;

      final claimed = await api.call(
        'POST',
        '/v1/orders/$orderId/claim',
        token: token,
        headers: <String, String>{'idempotency-key': 'claim-ok'},
        body: <String, Object?>{'phoneLast4': '4567'},
      );
      expect(claimed.status, 200, reason: claimed.text);
      expect(Order.fromJson(claimed.object).id, orderId);
      expect(api.server.orders[orderId]!.ownerId, 'cus_demo');

      final history = await api.call('GET', '/v1/orders', token: token);
      final page = OrderHistoryPage.fromJson(history.object);
      expect(page.orders.map((entry) => entry.id), contains(orderId));

      final guestView = await api.call(
        'GET',
        '/v1/orders/$orderId',
        token: guestToken,
      );
      expect(guestView.status, 200, reason: guestView.text);

      final again = await api.call(
        'POST',
        '/v1/orders/$orderId/claim',
        token: token,
        headers: <String, String>{'idempotency-key': 'claim-ok'},
        body: <String, Object?>{'phoneLast4': '4567'},
      );
      expect(again.status, 200, reason: again.text);
      expect(api.server.orders[orderId]!.ownerId, 'cus_demo');
    });
  });
}
