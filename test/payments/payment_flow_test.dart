import 'package:api_contract/api_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/payments/payment_flow.dart';

import '../features/support/fixtures.dart';

void main() {
  PaymentIntent intent(PaymentStatus status) => PaymentIntent(
    id: 'int_1',
    orderId: 'ord_1',
    status: status,
    amount: byn(2600),
    provider: 'bepaid',
    createdAt: testNow,
    methodId: 'bank_card',
  );

  group('PaymentFlow', () {
    test('стартует в idle и идёт только вперёд', () {
      const flow = PaymentFlow.initial();
      expect(flow.phase, PaymentPhase.idle);
      expect(flow.canCreateIntent, isTrue);

      final preparing = flow.moveTo(PaymentPhase.preparing);
      expect(preparing?.phase, PaymentPhase.preparing);

      final waiting = preparing!.moveTo(PaymentPhase.awaitingUser);
      expect(waiting?.phase, PaymentPhase.awaitingUser);

      final polling = waiting!.moveTo(PaymentPhase.polling);
      expect(polling?.phase, PaymentPhase.polling);

      final paid = polling!.applyStatus(
        PaymentStatus.succeeded,
        intent: intent(PaymentStatus.succeeded),
      );
      expect(paid.phase, PaymentPhase.succeeded);
      expect(paid.isTerminal, isTrue);
    });

    test('обратный переход запрещён даже при чужом ответе', () {
      final paid = const PaymentFlow().applyStatus(
        PaymentStatus.succeeded,
        intent: intent(PaymentStatus.succeeded),
      );
      expect(paid.moveTo(PaymentPhase.polling), isNull);
      final stale = paid.applyStatus(
        PaymentStatus.failed,
        intent: intent(PaymentStatus.failed),
      );
      expect(stale.phase, PaymentPhase.succeeded);
      expect(stale.intent?.status, PaymentStatus.failed);
    });

    test('после succeeded новый intent не создаётся', () {
      final paid = const PaymentFlow().applyStatus(PaymentStatus.succeeded);
      expect(paid.canCreateIntent, isFalse);
    });

    test('каждый серверный статус отображается в свою фазу', () {
      final base = const PaymentFlow()
          .moveTo(PaymentPhase.preparing)!
          .moveTo(PaymentPhase.awaitingUser)!;
      expect(
        base.applyStatus(PaymentStatus.created).phase,
        PaymentPhase.awaitingUser,
      );
      expect(
        base.applyStatus(PaymentStatus.requiresAction).phase,
        PaymentPhase.awaitingUser,
      );
      expect(
        base.applyStatus(PaymentStatus.pendingUser).phase,
        PaymentPhase.awaitingUser,
      );
      expect(
        base.applyStatus(PaymentStatus.processing).phase,
        PaymentPhase.polling,
      );
      expect(
        base.applyStatus(PaymentStatus.pendingOnDelivery).phase,
        PaymentPhase.onDelivery,
      );
      expect(base.applyStatus(PaymentStatus.failed).phase, PaymentPhase.failed);
      expect(
        base.applyStatus(PaymentStatus.expired).phase,
        PaymentPhase.expired,
      );
      expect(
        base.applyStatus(PaymentStatus.canceled).phase,
        PaymentPhase.canceled,
      );
      expect(
        base.applyStatus(PaymentStatus.refunded).phase,
        PaymentPhase.succeeded,
      );
      expect(
        base.applyStatus(PaymentStatus.partiallyRefunded).phase,
        PaymentPhase.succeeded,
      );
    });

    test('неизвестный статус не выдаётся за оплату', () {
      final unknown = const PaymentFlow()
          .moveTo(PaymentPhase.preparing)!
          .moveTo(PaymentPhase.awaitingUser)!
          .moveTo(PaymentPhase.polling)!
          .applyStatus(PaymentStatus.unknown);
      expect(unknown.phase, PaymentPhase.polling);
      expect(unknown.uncertain, isTrue);
      expect(unknown.phase.isTerminal, isFalse);
    });

    test('оплату при получении нельзя показать как оплаченную', () {
      final cod = const PaymentFlow().applyStatus(
        PaymentStatus.pendingOnDelivery,
      );
      expect(cod.phase, PaymentPhase.onDelivery);
      expect(cod.phase, isNot(PaymentPhase.succeeded));
      expect(cod.isTerminal, isFalse);
    });
  });

  group('paymentCallToAction', () {
    test('неоплаченный заказ предлагает оплату', () {
      expect(paymentCallToAction(orderFixture()), PaymentCallToAction.pay);
    });

    test('оплаченный заказ показывает чек, а не оплату', () {
      expect(
        paymentCallToAction(
          orderFixture(paymentStatus: PaymentStatus.succeeded),
        ),
        PaymentCallToAction.receipt,
      );
    });

    test('заказ на 0 BYN (PIC100) не предлагает оплату', () {
      final zero = Order(
        id: 'ord_pic100',
        number: 'PP-1002',
        createdAt: testNow,
        updatedAt: testNow,
        items: const <OrderItem>[],
        totals: OrderTotals(
          subtotal: byn(0),
          discount: byn(0),
          delivery: byn(0),
          total: byn(0),
        ),
        delivery: const OrderDelivery(
          kind: DeliveryKind.pickup,
          optionId: 'pickup_main',
          pointId: 'main',
        ),
        paymentStatus: PaymentStatus.succeeded,
        fulfillmentStatus: OrderStatus.placed,
        history: const <OrderStatusEvent>[],
      );
      expect(zero.paymentStatus.isPaid, isTrue);
      expect(zero.totals.total.isZero, isTrue);
      expect(paymentCallToAction(zero), isNot(PaymentCallToAction.pay));
    });

    test('отменённый заказ не предлагает оплату', () {
      expect(
        paymentCallToAction(
          orderFixture(fulfillmentStatus: OrderStatus.canceled),
        ),
        PaymentCallToAction.none,
      );
    });

    test('оплата при получении уже выбрана', () {
      expect(
        paymentCallToAction(
          orderFixture(paymentStatus: PaymentStatus.pendingOnDelivery),
        ),
        PaymentCallToAction.none,
      );
    });
  });
}
