import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  group('orders', () {
    test('round-trips an order with both status axes', () {
      final source = order();
      final decoded = roundTrip(source.toJson(), Order.fromJson);
      expect(decoded, source);
      expect(decoded.number, 'PP-1001');
      expect(decoded.totals.total.amountMinor, 1170);
      expect(decoded.totals.discount.isRefund, isTrue);
      expect(decoded.delivery.isPickup, isTrue);
      expect(decoded.delivery.pickupCode, '4821');
      expect(decoded.history.single.status, OrderStatus.accepted);
    });

    test('payment and fulfillment stay independent', () {
      final paidNotProduced = order(
        paymentStatus: 'succeeded',
        fulfillmentStatus: 'moderation',
      );
      expect(paidNotProduced.isPaid, isTrue);
      expect(paidNotProduced.fulfillmentStatus, OrderStatus.moderation);
      expect(paidNotProduced.isCompleted, isFalse);

      final producedNotPaid = order(
        paymentStatus: 'pending_on_delivery',
        fulfillmentStatus: 'completed',
      );
      expect(producedNotPaid.isPaid, isFalse);
      expect(producedNotPaid.isCashOnDelivery, isTrue);
      expect(producedNotPaid.isCompleted, isTrue);
    });

    test('timestamps are normalised to UTC', () {
      final parsed = order();
      expect(parsed.createdAt.isUtc, isTrue);
      expect(parsed.createdAt.hour, 6); // 09:00+03:00
      expect(parsed.updatedAt.isUtc, isTrue);
      expect(parsed.eta!.isUtc, isTrue);
    });

    test('status message keys follow the documented convention', () {
      expect(
        OrderStatus.readyForPickup.messageKey,
        'order.status.ready_for_pickup',
      );
      expect(PaymentStatus.partiallyRefunded.isPaid, isTrue);
      expect(PaymentStatus.requiresAction.isPending, isTrue);
      expect(OrderStatus.unknown.messageKey, 'order.status.unknown');
    });

    test('round-trips a history page with a cursor', () {
      final page = OrderHistoryPage(
        orders: <Order>[
          order(),
          order(fulfillmentStatus: 'shipped'),
        ],
        nextCursor: 'c-2',
      );
      final decoded = roundTrip(page.toJson(), OrderHistoryPage.fromJson);
      expect(decoded, page);
      expect(decoded.hasMore, isTrue);
      expect(decoded.orders.length, 2);
    });

    test('missing totals is invalid_response with a path', () {
      final json = orderJson()..remove('totals');
      final result = decodeJson(json, Order.fromJson);
      expect(result.failureOrNull!.code, ApiErrorCode.invalidResponse);
      expect(result.failureOrNull!.args['path'], r'$.totals');
    });

    test('a missing item price is invalid_response with an indexed path', () {
      final json = orderJson();
      final items = json['items']! as List<Object?>;
      ((items.single! as Map<String, Object?>)['unitPrice']!
              as Map<String, Object?>)
          .remove('amountMinor');
      final result = decodeJson(json, Order.fromJson);
      expect(
        result.failureOrNull!.args['path'],
        r'$.items[0].unitPrice.amountMinor',
      );
    });

    test('round-trips checkout and direct order requests', () {
      final checkout = CheckoutRequest(
        cartId: 'c1',
        delivery: DeliverySelection(
          kind: DeliveryKind.pickup,
          optionId: 'pickup_main',
          pointId: 'main',
          slot: DateTime.utc(2026, 11, 14, 7),
        ),
        contact: const ContactInfo(name: 'Тест', phone: '+375000000000'),
        promoCode: 'TEST10',
      );
      expect(roundTrip(checkout.toJson(), CheckoutRequest.fromJson), checkout);

      final direct = CreateOrderRequest(
        lines: const <OrderLineRequest>[
          OrderLineRequest(designId: 'd1', quantity: 10),
        ],
        delivery: const DeliverySelection(kind: DeliveryKind.courier),
        contact: const ContactInfo(name: 'Тест', phone: '+375000000000'),
      );
      expect(roundTrip(direct.toJson(), CreateOrderRequest.fromJson), direct);
    });
  });

  group('payments', () {
    test('round-trips a payment intent with hosted page', () {
      final intent = PaymentIntent(
        id: 'pi1',
        orderId: 'o1',
        status: PaymentStatus.requiresAction,
        amount: const Money(amountMinor: 1170, currency: 'BYN'),
        provider: 'mock_psp',
        createdAt: DateTime.utc(2026, 11, 11, 9),
        methodId: 'bank_card',
        hostedPageUrl: 'https://pay.example/pi1',
        expiresAt: DateTime.utc(2026, 11, 11, 9, 15),
      );
      final decoded = roundTrip(intent.toJson(), PaymentIntent.fromJson);
      expect(decoded, intent);
      expect(decoded.requiresUserAction, isTrue);
      expect(decoded.status.isPending, isTrue);
      expect(decoded.amount.currency, 'BYN');
    });

    test('unknown payment status is representable', () {
      final json = <String, Object?>{
        'id': 'pi1',
        'orderId': 'o1',
        'status': 'quantum',
        'amount': <String, Object?>{'amountMinor': 100, 'currency': 'BYN'},
        'provider': 'mock_psp',
        'createdAt': '2026-11-11T09:00:00Z',
      };
      final decoded = roundTrip(json, PaymentIntent.fromJson);
      expect(decoded.status, PaymentStatus.unknown);
      expect(decoded.status.isPending, isFalse);
      expect(decoded.status.isTerminal, isFalse);
    });

    test('rejects a negative intent amount', () {
      final json = <String, Object?>{
        'id': 'pi1',
        'orderId': 'o1',
        'status': 'created',
        'amount': <String, Object?>{'amountMinor': -100, 'currency': 'BYN'},
        'provider': 'mock_psp',
        'createdAt': '2026-11-11T09:00:00Z',
      };
      final result = decodeJson(json, PaymentIntent.fromJson);
      expect(result.failureOrNull!.code, ApiErrorCode.invalidMoney);
    });

    test('round-trips receipt, refund and payment method', () {
      final receipt = Receipt(
        id: 'r1',
        orderId: 'o1',
        fiscalId: 'F-1',
        amount: const Money(amountMinor: 1170, currency: 'BYN'),
        issuedAt: DateTime.utc(2026, 11, 11, 9),
        url: 'https://receipt.example/r1',
        vat: const Money(amountMinor: 195, currency: 'BYN'),
      );
      expect(roundTrip(receipt.toJson(), Receipt.fromJson), receipt);

      final refund = Refund(
        id: 'rf1',
        orderId: 'o1',
        amount: const Money(amountMinor: 1170, currency: 'BYN'),
        status: RefundStatus.pending,
        createdAt: DateTime.utc(2026, 11, 12),
        reasonKey: 'refund.defect',
      );
      expect(roundTrip(refund.toJson(), Refund.fromJson), refund);

      const method = PaymentMethodInfo(
        id: 'erip',
        titleKey: 'payment.erip',
        kind: 'erip',
        currency: 'BYN',
        region: 'BY',
        requiresRedirect: false,
      );
      expect(roundTrip(method.toJson(), PaymentMethodInfo.fromJson), method);
    });
  });
}
