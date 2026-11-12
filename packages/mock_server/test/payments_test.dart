import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:mock_server/mock_server.dart';
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

  Future<Map<String, Object?>> newOrder({int quantity = 10, String? promo}) =>
      api.placeOrder(
        token,
        quantity: quantity,
        idempotencyKey: 'order-${DateTime.now().microsecondsSinceEpoch}',
        promoCode: promo,
      );

  Future<MockResponse> createIntent(
    String orderId, {
    String key = 'intent-key-1',
    String methodId = 'bank_card',
  }) => api.call(
    'POST',
    '/v1/orders/$orderId/payment-intent',
    token: token,
    headers: <String, String>{'idempotency-key': key},
    body: <String, Object?>{'orderId': orderId, 'methodId': methodId},
  );

  group('payment methods', () {
    test('serves the BY and RU method sets', () async {
      final by = await api.call('GET', '/v1/payments/methods?region=BY');
      expect(by.status, 200, reason: by.text);
      final byMethods = <PaymentMethodInfo>[
        for (final raw in by.list)
          PaymentMethodInfo.fromJson((raw! as Map).cast<String, Object?>()),
      ];
      expect(
        byMethods.map((method) => method.id),
        containsAll(<String>['bank_card', 'erip', 'cash_on_delivery']),
      );
      expect(byMethods.every((method) => method.currency == 'BYN'), isTrue);

      final ru = await api.call('GET', '/v1/payments/methods?region=RU');
      final ruMethods = <PaymentMethodInfo>[
        for (final raw in ru.list)
          PaymentMethodInfo.fromJson((raw! as Map).cast<String, Object?>()),
      ];
      expect(
        ruMethods.map((method) => method.id),
        containsAll(<String>['bank_card', 'sbp']),
      );
      expect(ruMethods.every((method) => method.currency == 'RUB'), isTrue);

      final unknown = await api.call('GET', '/v1/payments/methods?region=KZ');
      expectError(unknown, 422, ApiErrorCode.validationFailed);
    });
  });

  group('payment intents', () {
    test(
      'creates a card intent with a real hosted page and no card fields',
      () async {
        final order = await newOrder();
        final response = await createIntent(order['id']! as String);
        expect(response.status, 201, reason: response.text);
        final intent = PaymentIntent.fromJson(response.object);
        expect(intent.status, PaymentStatus.requiresAction);
        expect(intent.amount.amountMinor, 1300);
        expect(intent.provider, 'bepaid');
        expect(intent.methodId, 'bank_card');
        expect(intent.hostedPageUrl, contains('/v1/mock/psp/hosted/'));
        expect(intent.requiresUserAction, isTrue);

        final hosted = Uri.parse(intent.hostedPageUrl!);
        final page = await api.call(
          'GET',
          '${hosted.path}?token=${hosted.queryParameters['token']}',
        );
        expect(page.status, 200, reason: page.text);
        expect(page.header('content-type'), contains('text/html'));
        expect(page.text, contains('Оплатить'));
        expect(page.text, contains('Отклонить'));
        expect(page.text.toLowerCase(), isNot(contains('cvv')));
        expect(page.text.toLowerCase(), isNot(contains('card number')));

        final withoutToken = await api.call(
          'GET',
          Uri.parse(intent.hostedPageUrl!).path,
        );
        expectError(withoutToken, 403, ApiErrorCode.forbidden);
      },
    );

    test(
      'replays the same intent for the same key and reuses the active one',
      () async {
        final order = await newOrder();
        final orderId = order['id']! as String;

        final first = await createIntent(orderId);
        final second = await createIntent(orderId);
        expect(first.status, 201);
        expect(second.status, 200);
        expect(second.object['id'], first.object['id']);
        expect(api.server.intents, hasLength(1));

        final third = await createIntent(orderId, key: 'other-key');
        expect(third.status, 200);
        expect(third.object['id'], first.object['id']);
        expect(api.server.intents, hasLength(1));

        final conflict = await api.call(
          'POST',
          '/v1/orders/$orderId/payment-intent',
          token: token,
          headers: <String, String>{'idempotency-key': 'intent-key-1'},
          body: <String, Object?>{'orderId': orderId, 'methodId': 'erip'},
        );
        expectError(conflict, 422, ApiErrorCode.idempotencyConflict);
      },
    );

    test('the hosted page completes the payment', () async {
      final order = await newOrder();
      final intent = PaymentIntent.fromJson(
        (await createIntent(order['id']! as String)).object,
      );
      final uri = Uri.parse(intent.hostedPageUrl!);
      final pay = await api.call(
        'POST',
        '${uri.path}/pay?token=${uri.queryParameters['token']}',
      );
      expect(pay.status, 200, reason: pay.text);
      expect(pay.text, contains('Оплата принята'));

      final polled = await api.call(
        'GET',
        '/v1/payments/${intent.id}',
        token: token,
      );
      expect(
        PaymentIntent.fromJson(polled.object).status,
        PaymentStatus.succeeded,
      );
      final paidOrder = Order.fromJson(
        (await api.call(
          'GET',
          '/v1/orders/${order['id']}',
          token: token,
        )).object,
      );
      expect(paidOrder.paymentStatus, PaymentStatus.succeeded);
      expect(paidOrder.fulfillmentStatus, OrderStatus.placed);
      expect(paidOrder.history, hasLength(1));

      final again = await createIntent(
        order['id']! as String,
        key: 'after-paid',
      );
      expectError(again, 409, 'payment_already_paid');
    });

    test('a declined page marks the payment failed', () async {
      final order = await newOrder();
      final intent = PaymentIntent.fromJson(
        (await createIntent(order['id']! as String)).object,
      );
      final uri = Uri.parse(intent.hostedPageUrl!);
      await api.call(
        'POST',
        '${uri.path}/decline?token=${uri.queryParameters['token']}',
      );
      final polled = PaymentIntent.fromJson(
        (await api.call(
          'GET',
          '/v1/payments/${intent.id}',
          token: token,
        )).object,
      );
      expect(polled.status, PaymentStatus.failed);
      expect(polled.failureCode, 'declined_by_user');
    });
  });

  group('webhooks', () {
    test('deduplicate by eventId and never roll a paid intent back', () async {
      final order = await newOrder();
      final intent = PaymentIntent.fromJson(
        (await createIntent(order['id']! as String)).object,
      );

      final first = await api.webhook('bepaid', <String, Object?>{
        'eventId': 'evt-1',
        'intentId': intent.id,
        'type': 'payment.succeeded',
      });
      expect(first.status, 200, reason: first.text);
      expect(first.object['duplicate'], isFalse);
      expect(first.object['changed'], isTrue);

      final duplicate = await api.webhook('bepaid', <String, Object?>{
        'eventId': 'evt-1',
        'intentId': intent.id,
        'type': 'payment.succeeded',
      });
      expect(duplicate.status, 200);
      expect(duplicate.object['duplicate'], isTrue);
      expect(duplicate.object['changed'], isFalse);

      final rollback = await api.webhook('bepaid', <String, Object?>{
        'eventId': 'evt-2',
        'intentId': intent.id,
        'type': 'payment.failed',
      });
      expect(rollback.status, 200);
      expect(rollback.object['changed'], isFalse);
      expect(rollback.object['status'], 'succeeded');

      final polled = PaymentIntent.fromJson(
        (await api.call(
          'GET',
          '/v1/payments/${intent.id}',
          token: token,
        )).object,
      );
      expect(polled.status, PaymentStatus.succeeded);
    });

    test('an unsigned webhook is rejected and pays nothing', () async {
      final order = await newOrder();
      final intent = PaymentIntent.fromJson(
        (await createIntent(order['id']! as String)).object,
      );

      final unsigned = await api.call(
        'POST',
        '/v1/webhooks/psp/bepaid',
        body: <String, Object?>{
          'eventId': 'evt-unsigned',
          'intentId': intent.id,
          'type': 'payment.succeeded',
        },
      );
      expectError(unsigned, 401, 'invalid_signature');

      final intentAfter = PaymentIntent.fromJson(
        (await api.call(
          'GET',
          '/v1/payments/${intent.id}',
          token: token,
        )).object,
      );
      expect(intentAfter.status, PaymentStatus.requiresAction);
      final orderAfter = Order.fromJson(
        (await api.call(
          'GET',
          '/v1/orders/${order['id']}',
          token: token,
        )).object,
      );
      expect(orderAfter.paymentStatus.isPaid, isFalse);
      expect(api.server.webhookSeen('bepaid', 'evt-unsigned'), isFalse);
    });

    test('a wrong, stale or mis-addressed signature is rejected', () async {
      final order = await newOrder();
      final intent = PaymentIntent.fromJson(
        (await createIntent(order['id']! as String)).object,
      );
      final event = <String, Object?>{
        'eventId': 'evt-sig',
        'intentId': intent.id,
        'type': 'payment.succeeded',
      };

      final wrongMac = await api.webhook('bepaid', event, signature: 'a' * 64);
      expectError(wrongMac, 401, 'invalid_signature');

      final stale = await api.webhook(
        'bepaid',
        event,
        timestamp: api.clock
            .now()
            .subtract(const Duration(minutes: 6))
            .toUtc()
            .toIso8601String(),
      );
      expectError(stale, 401, 'invalid_signature');

      final notIso = await api.webhook(
        'bepaid',
        event,
        timestamp: 'not-a-date',
      );
      expectError(notIso, 401, 'invalid_signature');

      final reDated = await api.call(
        'POST',
        '/v1/webhooks/psp/bepaid',
        body: event,
        headers: <String, String>{
          'x-psp-timestamp': api.clock.now().toUtc().toIso8601String(),
          'x-psp-signature': _macOf(
            event,
            api.clock.now().subtract(const Duration(minutes: 1)),
          ),
        },
      );
      expectError(reDated, 401, 'invalid_signature');

      final stillPending = PaymentIntent.fromJson(
        (await api.call(
          'GET',
          '/v1/payments/${intent.id}',
          token: token,
        )).object,
      );
      expect(stillPending.status, PaymentStatus.requiresAction);

      final signed = await api.webhook('bepaid', event);
      expect(signed.status, 200, reason: signed.text);
      expect(signed.object['changed'], isTrue);
    });

    test('reject a provider mismatch and an unsupported type', () async {
      final order = await newOrder();
      final intent = PaymentIntent.fromJson(
        (await createIntent(order['id']! as String)).object,
      );
      final wrongProvider = await api.webhook('yookassa', <String, Object?>{
        'eventId': 'evt-x',
        'intentId': intent.id,
        'type': 'payment.succeeded',
      });
      expectError(wrongProvider, 422, ApiErrorCode.validationFailed);

      final unsupported = await api.webhook('bepaid', <String, Object?>{
        'eventId': 'evt-y',
        'intentId': intent.id,
        'type': 'payment.teleported',
      });
      expectError(unsupported, 422, ApiErrorCode.validationFailed);
    });
  });

  group('simulator scenarios', () {
    test('timeout_then_webhook completes lazily on the next request', () async {
      final order = await newOrder();
      final intent = PaymentIntent.fromJson(
        (await createIntent(order['id']! as String)).object,
      );

      final simulated = await api.call(
        'POST',
        '/v1/mock/psp/simulate',
        token: await support(),
        body: <String, Object?>{
          'scenario': 'timeout_then_webhook',
          'intentId': intent.id,
        },
      );
      expect(simulated.status, 200, reason: simulated.text);
      expect((simulated.object['intent']! as Map)['status'], 'processing');

      api.clock.advance(const Duration(seconds: 3));
      final polled = PaymentIntent.fromJson(
        (await api.call(
          'GET',
          '/v1/payments/${intent.id}',
          token: token,
        )).object,
      );
      expect(polled.status, PaymentStatus.succeeded);
    });

    test('3DS, insufficient funds and duplicate webhook', () async {
      final order = await newOrder();
      final orderId = order['id']! as String;
      final intent = PaymentIntent.fromJson(
        (await createIntent(orderId)).object,
      );

      final challenge = await api.call(
        'POST',
        '/v1/mock/psp/simulate',
        token: await support(),
        body: <String, Object?>{
          'scenario': '3ds_challenge',
          'intentId': intent.id,
        },
      );
      expect((challenge.object['intent']! as Map)['status'], 'requires_action');

      final failed = await api.call(
        'POST',
        '/v1/mock/psp/simulate',
        token: await support(),
        body: <String, Object?>{
          'scenario': 'insufficient_funds',
          'intentId': intent.id,
        },
      );
      expect((failed.object['intent']! as Map)['status'], 'failed');
      expect(
        (failed.object['intent']! as Map)['failureCode'],
        'insufficient_funds',
      );

      final secondIntent = PaymentIntent.fromJson(
        (await createIntent(orderId, key: 'second-intent')).object,
      );
      final duplicate = await api.call(
        'POST',
        '/v1/mock/psp/simulate',
        token: await support(),
        body: <String, Object?>{
          'scenario': 'duplicate_webhook',
          'intentId': secondIntent.id,
        },
      );
      expect(duplicate.status, 200, reason: duplicate.text);
      expect((duplicate.object['intent']! as Map)['status'], 'succeeded');
      expect(
        api.server.webhookSeen('bepaid', 'sim-duplicate-${secondIntent.id}'),
        isTrue,
      );
    });

    test('a COD order is confirmed at handover', () async {
      final order = await newOrder();
      final orderId = order['id']! as String;
      final intent = PaymentIntent.fromJson(
        (await createIntent(orderId, methodId: 'cash_on_delivery')).object,
      );
      expect(intent.status, PaymentStatus.pendingOnDelivery);
      expect(intent.hostedPageUrl, isNull);
      expect(
        Order.fromJson(
          (await api.call('GET', '/v1/orders/$orderId', token: token)).object,
        ).isCashOnDelivery,
        isTrue,
      );

      final confirmed = await api.call(
        'POST',
        '/v1/mock/psp/simulate',
        token: await support(),
        body: <String, Object?>{
          'scenario': 'cod_confirm',
          'intentId': intent.id,
        },
      );
      expect((confirmed.object['intent']! as Map)['status'], 'succeeded');
    });

    test('zero_amount reports a paid promo order and has no intent', () async {
      final order = await newOrder(promo: 'PIC100');
      final orderId = order['id']! as String;
      final response = await api.call(
        'POST',
        '/v1/mock/psp/simulate',
        token: await support(),
        body: <String, Object?>{'scenario': 'zero_amount', 'orderId': orderId},
      );
      expect(response.status, 200, reason: response.text);
      expect((response.object['order']! as Map)['paymentStatus'], 'succeeded');
      expect(response.object['intent'], isNull);

      final intent = await createIntent(orderId, key: 'zero-key');
      expectError(intent, 409, 'payment_already_paid');
      expect(api.server.intents, isEmpty);
    });
  });

  group('refunds and receipts', () {
    test(
      'a customer cannot refund: money moves through support only',
      () async {
        final order = await newOrder();
        final orderId = order['id']! as String;
        final intent = PaymentIntent.fromJson(
          (await createIntent(orderId)).object,
        );
        await api.webhook('bepaid', <String, Object?>{
          'eventId': 'evt-refund-denied',
          'intentId': intent.id,
          'type': 'payment.succeeded',
        });

        final denied = await api.call(
          'POST',
          '/v1/orders/$orderId/refunds',
          token: token,
          headers: <String, String>{'idempotency-key': 'self-refund'},
          body: <String, Object?>{
            'orderId': orderId,
            'amountMinor': 1300,
            'reasonKey': 'refund.damaged',
          },
        );
        expectError(denied, 403, 'refund_requires_support');
        expect(api.server.refunds, isEmpty);

        final audit = await api.call(
          'GET',
          '/v1/audit?limit=100',
          token: await support(),
        );
        expect(audit.status, 200, reason: audit.text);
        final records = <AuditRecord>[
          for (final raw in audit.list)
            AuditRecord.fromJson((raw! as Map).cast<String, Object?>()),
        ];
        final refusal = records.singleWhere(
          (record) => record.action == 'payment.refund',
        );
        expect(refusal.result, 'denied');
      },
    );

    test('full refund settles the intent and keeps the order paid', () async {
      final order = await newOrder();
      final orderId = order['id']! as String;
      final intent = PaymentIntent.fromJson(
        (await createIntent(orderId)).object,
      );
      await api.webhook('bepaid', <String, Object?>{
        'eventId': 'evt-refund',
        'intentId': intent.id,
        'type': 'payment.succeeded',
      });

      final refund = await api.call(
        'POST',
        '/v1/orders/$orderId/refunds',
        token: await support(),
        headers: <String, String>{'idempotency-key': 'refund-1'},
        body: <String, Object?>{
          'orderId': orderId,
          'amountMinor': 1300,
          'reasonKey': 'refund.damaged',
        },
      );
      expect(refund.status, 201, reason: refund.text);
      final parsedRefund = Refund.fromJson(refund.object);
      expect(parsedRefund.amount.amountMinor, 1300);
      expect(parsedRefund.status, RefundStatus.succeeded);

      final polledIntent = PaymentIntent.fromJson(
        (await api.call(
          'GET',
          '/v1/payments/${intent.id}',
          token: token,
        )).object,
      );
      expect(polledIntent.status, PaymentStatus.refunded);

      final orderAfter = Order.fromJson(
        (await api.call('GET', '/v1/orders/$orderId', token: token)).object,
      );
      expect(orderAfter.isPaid, isTrue);
      expect(orderAfter.fulfillmentStatus, OrderStatus.placed);

      final second = await api.call(
        'POST',
        '/v1/orders/$orderId/refunds',
        token: await support(),
        headers: <String, String>{'idempotency-key': 'refund-2'},
        body: <String, Object?>{
          'orderId': orderId,
          'amountMinor': 100,
          'reasonKey': 'refund.other',
        },
      );
      expectError(second, 409, 'already_refunded');
    });

    test('partial refunds accumulate and never exceed the total', () async {
      final order = await newOrder();
      final orderId = order['id']! as String;
      final intent = PaymentIntent.fromJson(
        (await createIntent(orderId)).object,
      );
      await api.webhook('bepaid', <String, Object?>{
        'eventId': 'evt-partial',
        'intentId': intent.id,
        'type': 'payment.succeeded',
      });

      final partial = await api.call(
        'POST',
        '/v1/orders/$orderId/refunds',
        token: await support(),
        headers: <String, String>{'idempotency-key': 'partial-1'},
        body: <String, Object?>{
          'orderId': orderId,
          'amountMinor': 500,
          'reasonKey': 'refund.partial',
        },
      );
      expect(partial.status, 201, reason: partial.text);
      expect(
        PaymentIntent.fromJson(
          (await api.call(
            'GET',
            '/v1/payments/${intent.id}',
            token: token,
          )).object,
        ).status,
        PaymentStatus.partiallyRefunded,
      );

      final tooMuch = await api.call(
        'POST',
        '/v1/orders/$orderId/refunds',
        token: await support(),
        headers: <String, String>{'idempotency-key': 'partial-2'},
        body: <String, Object?>{
          'orderId': orderId,
          'amountMinor': 900,
          'reasonKey': 'refund.too_much',
        },
      );
      expectError(tooMuch, 422, ApiErrorCode.validationFailed);
      expect(fieldErrors(tooMuch)['amountMinor'], 'out_of_range');

      final rest = await api.call(
        'POST',
        '/v1/orders/$orderId/refunds',
        token: await support(),
        headers: <String, String>{'idempotency-key': 'partial-3'},
        body: <String, Object?>{
          'orderId': orderId,
          'amountMinor': 800,
          'reasonKey': 'refund.rest',
        },
      );
      expect(rest.status, 201, reason: rest.text);
      expect(
        PaymentIntent.fromJson(
          (await api.call(
            'GET',
            '/v1/payments/${intent.id}',
            token: token,
          )).object,
        ).status,
        PaymentStatus.refunded,
      );
    });

    test('issues a receipt only for a paid order', () async {
      final order = await newOrder();
      final orderId = order['id']! as String;

      final unavailable = await api.call(
        'GET',
        '/v1/orders/$orderId/receipt',
        token: token,
      );
      expectError(unavailable, 409, 'receipt_not_available');

      final intent = PaymentIntent.fromJson(
        (await createIntent(orderId)).object,
      );
      await api.webhook('bepaid', <String, Object?>{
        'eventId': 'evt-receipt',
        'intentId': intent.id,
        'type': 'payment.succeeded',
      });

      final receiptResponse = await api.call(
        'GET',
        '/v1/orders/$orderId/receipt',
        token: token,
      );
      expect(receiptResponse.status, 200, reason: receiptResponse.text);
      final receipt = Receipt.fromJson(receiptResponse.object);
      expect(receipt.amount.amountMinor, 1300);
      expect(receipt.fiscalId, startsWith('FISC-'));
      expect(receipt.url, contains('/v1/mock/receipts/'));

      final page = await api.call('GET', Uri.parse(receipt.url!).path);
      expect(page.status, 200);
      expect(page.header('content-type'), contains('text/html'));

      final repeated = await api.call(
        'GET',
        '/v1/orders/$orderId/receipt',
        token: token,
      );
      expect(repeated.object['id'], receipt.id);
    });
  });
}

String _macOf(Map<String, Object?> event, DateTime timestamp) =>
    pspWebhookSignature(
      secret: testWebhookSecret,
      timestamp: timestamp.toUtc().toIso8601String(),
      body: utf8.encode(jsonEncode(event)),
    );
