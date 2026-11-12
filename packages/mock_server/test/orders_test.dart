import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  late MockApi api;
  late String token;
  String? supportToken;

  setUp(() async {
    api = MockApi();
    token = await api.login();
    supportToken = null;
  });

  Future<String> support() async => supportToken ??= await api.loginSupport();

  group('order history', () {
    test('lists own orders newest first with a cursor', () async {
      await api.placeOrder(token, idempotencyKey: 'a');
      api.clock.advance(const Duration(minutes: 1));
      await api.placeOrder(token, idempotencyKey: 'b', quantity: 2);

      final response = await api.call('GET', '/v1/orders', token: token);
      expect(response.status, 200, reason: response.text);
      final page = OrderHistoryPage.fromJson(response.object);
      expect(page.orders, hasLength(2));
      expect(page.orders.first.number, 'PP-1002');
      expect(page.nextCursor, isNull);

      final filtered = await api.call(
        'GET',
        '/v1/orders?status=placed&limit=1',
        token: token,
      );
      final firstPage = OrderHistoryPage.fromJson(filtered.object);
      expect(firstPage.orders, hasLength(1));
      expect(firstPage.nextCursor, '1');

      final secondPage = await api.call(
        'GET',
        '/v1/orders?status=placed&limit=1&cursor=${firstPage.nextCursor}',
        token: token,
      );
      expect(OrderHistoryPage.fromJson(secondPage.object).orders, hasLength(1));
    });

    test(
      'hides an order of another customer and lets support read it',
      () async {
        final other = api.registerCustomer('cus_other');
        final design = await api.call(
          'POST',
          '/v1/designs',
          token: other,
          body: printDesignJson(),
        );
        final orderResponse = await api.directOrder(
          other,
          design.object['id']! as String,
        );
        final orderId = orderResponse.object['id']! as String;

        final foreign = await api.call(
          'GET',
          '/v1/orders/$orderId',
          token: token,
        );
        expectError(foreign, 403, ApiErrorCode.forbidden);

        final support = await api.loginSupport();
        final visible = await api.call(
          'GET',
          '/v1/orders/$orderId',
          token: support,
        );
        expect(visible.status, 200, reason: visible.text);
        expect(Order.fromJson(visible.object).id, orderId);
      },
    );
  });

  test('a guest gets no order history', () async {
    final guest = await api.anonymous();
    final response = await api.call('GET', '/v1/orders', token: guest);
    expectError(response, 403, ApiErrorCode.forbidden);
  });

  group('status machine', () {
    test(
      'a customer can only cancel; production is support business',
      () async {
        final order = await api.placeOrder(token);
        final id = order['id']! as String;

        final denied = await api.call(
          'POST',
          '/v1/mock/orders/$id/advance',
          token: token,
          body: <String, Object?>{},
        );
        expectError(denied, 403, 'advance_requires_support');
        expect(api.server.orders[id]!.fulfillmentStatus, 'placed');

        final forced = await api.call(
          'POST',
          '/v1/mock/orders/$id/advance',
          token: token,
          body: <String, Object?>{'to': 'quantum_ready', 'force': true},
        );
        expectError(forced, 403, 'advance_requires_support');
        expect(api.server.orders[id]!.fulfillmentStatus, 'placed');

        final canceled = await api.call(
          'POST',
          '/v1/mock/orders/$id/advance',
          token: token,
          body: <String, Object?>{'to': 'canceled'},
        );
        expect(canceled.status, 200, reason: canceled.text);
        expect(
          Order.fromJson(canceled.object).fulfillmentStatus,
          OrderStatus.canceled,
        );

        final again = await api.call(
          'POST',
          '/v1/mock/orders/$id/advance',
          token: token,
          body: <String, Object?>{'to': 'canceled'},
        );
        expectError(again, 409, 'invalid_transition');
      },
    );

    test('a stranger cannot advance somebody else\'s order', () async {
      final order = await api.placeOrder(token);
      final other = api.registerCustomer('cus_other');
      final response = await api.call(
        'POST',
        '/v1/mock/orders/${order['id']}/advance',
        token: other,
        body: <String, Object?>{'to': 'canceled'},
      );
      expectError(response, 403, ApiErrorCode.forbidden);
    });

    test('moves forward only and records a history feed', () async {
      final order = await api.placeOrder(token);
      final id = order['id']! as String;

      final expected = <String>[
        'accepted',
        'moderation',
        'production',
        'ready_for_pickup',
        'completed',
      ];
      for (final status in expected) {
        final response = await api.call(
          'POST',
          '/v1/mock/orders/$id/advance',
          token: await support(),
          body: <String, Object?>{},
        );
        expect(response.status, 200, reason: response.text);
        expect(Order.fromJson(response.object).fulfillmentStatus.wire, status);
      }

      final finalOrder = Order.fromJson(
        (await api.call('GET', '/v1/orders/$id', token: token)).object,
      );
      expect(finalOrder.fulfillmentStatus, OrderStatus.completed);
      expect(finalOrder.isCompleted, isTrue);
      expect(finalOrder.history.map((event) => event.status.wire), <String>[
        'placed',
        'accepted',
        'moderation',
        'production',
        'ready_for_pickup',
        'completed',
      ]);
      expect(finalOrder.history.every((event) => event.at.isUtc), isTrue);
    });

    test('rejects a backward transition and a terminal advance', () async {
      final order = await api.placeOrder(token);
      final id = order['id']! as String;
      await api.call(
        'POST',
        '/v1/mock/orders/$id/advance',
        token: await support(),
        body: <String, Object?>{},
      ); // accepted

      final backward = await api.call(
        'POST',
        '/v1/mock/orders/$id/advance',
        token: await support(),
        body: <String, Object?>{'to': 'placed'},
      );
      expectError(backward, 409, 'invalid_transition');
      expect(backward.object['from'], 'accepted');
      expect(backward.object['to'], 'placed');

      for (var i = 0; i < 4; i++) {
        await api.call(
          'POST',
          '/v1/mock/orders/$id/advance',
          token: await support(),
          body: <String, Object?>{},
        );
      }
      final terminal = await api.call(
        'POST',
        '/v1/mock/orders/$id/advance',
        token: await support(),
        body: <String, Object?>{},
      );
      expectError(terminal, 409, 'invalid_transition');
    });

    test('serialises an unknown status without breaking the client', () async {
      final order = await api.placeOrder(token);
      final id = order['id']! as String;
      final advanced = await api.call(
        'POST',
        '/v1/mock/orders/$id/advance',
        token: await support(),
        body: <String, Object?>{'to': 'quantum_ready', 'force': true},
      );
      expect(advanced.status, 200, reason: advanced.text);
      expect(advanced.object['fulfillmentStatus'], 'quantum_ready');

      final parsed = Order.fromJson(advanced.object);
      expect(parsed.fulfillmentStatus, OrderStatus.unknown);
      expect(parsed.hasUnknownStatus, isTrue);
      expect(parsed.fulfillmentStatus.messageKey, 'order.status.unknown');

      final list = await api.call('GET', '/v1/orders', token: token);
      final page = OrderHistoryPage.fromJson(list.object);
      expect(page.orders.single.fulfillmentStatus, OrderStatus.unknown);
    });

    test('an unknown status without force is a validation error', () async {
      final order = await api.placeOrder(token);
      final response = await api.call(
        'POST',
        '/v1/mock/orders/${order['id']}/advance',
        token: await support(),
        body: <String, Object?>{'to': 'quantum_ready'},
      );
      expectError(response, 422, ApiErrorCode.validationFailed);
      expect(fieldErrors(response)['to'], 'unknown_status');
    });

    test('payment events never move the fulfilment axis', () async {
      final order = await api.placeOrder(token);
      final orderId = order['id']! as String;
      final intentResponse = await api.call(
        'POST',
        '/v1/orders/$orderId/payment-intent',
        token: token,
        headers: <String, String>{'idempotency-key': 'pay-1'},
        body: <String, Object?>{'orderId': orderId, 'methodId': 'bank_card'},
      );
      expect(intentResponse.status, 201, reason: intentResponse.text);
      final intentId = intentResponse.object['id']! as String;

      await api.webhook('bepaid', <String, Object?>{
        'eventId': 'evt-no-fulfilment',
        'intentId': intentId,
        'type': 'payment.succeeded',
      });
      final updated = Order.fromJson(
        (await api.call('GET', '/v1/orders/$orderId', token: token)).object,
      );
      expect(updated.paymentStatus, PaymentStatus.succeeded);
      expect(updated.fulfillmentStatus, OrderStatus.placed);
    });
  });
}
