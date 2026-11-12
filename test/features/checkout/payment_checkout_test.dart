import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:picpac_mobile/app/router.dart';
import 'package:picpac_mobile/payments/hosted_page_launcher.dart';
import 'package:picpac_mobile/payments/payment_controller.dart';
import 'package:picpac_mobile/payments/payment_port.dart';

import '../../payments/support/payment_fakes.dart';
import '../support/fixtures.dart';
import '../support/funnel_harness.dart';

void main() {
  setUpAll(registerFunnelFallbacks);

  void stubCheckoutData(FunnelHarness harness) {
    when(() => harness.api.cart()).thenAnswer(
      (_) async => Ok<Cart>(cartFixture(quantity: 1, subtotal: 1300)),
    );
    when(() => harness.api.catalog())
        .thenAnswer((_) async => Ok<CatalogResponse>(catalogResponse()));
    when(() => harness.api.design('dsg_1'))
        .thenAnswer((_) async => Ok<DesignDto>(designFixture()));
    when(() => harness.api.deliveryOptions()).thenAnswer(
      (_) async =>
          Ok<List<DeliveryOption>>(<DeliveryOption>[deliveryOption(price: 0)]),
    );
    when(() => harness.api.pickupPoints()).thenAnswer(
      (_) async => Ok<List<PickupPoint>>(<PickupPoint>[pickupPoint()]),
    );
    when(() => harness.api.price(any()))
        .thenAnswer((_) async => Ok<PriceQuote>(priceQuote(total: 2600)));
    when(() => harness.api.preflight(any(), revision: any(named: 'revision')))
        .thenAnswer(
          (_) async =>
              Ok<PreflightDto>(const PreflightDto(revision: 1, canOrder: true)),
        );
    when(() => harness.api.paymentMethods(region: any(named: 'region')))
        .thenAnswer(
          (_) async => Ok<List<PaymentMethodInfo>>(const <PaymentMethodInfo>[]),
        );
  }

  Future<void> placeOrder(WidgetTester tester, FunnelHarness harness) async {
    await harness.pump(tester);
    harness.go(AppRoutes.checkout);
    await harness.settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('checkout-name')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await harness.settle(tester);
    await tester.enterText(find.byKey(const Key('checkout-name')), 'Тест');
    await tester.enterText(
      find.byKey(const Key('checkout-phone')),
      '+375 29 123 45 67',
    );
    await tester.pump();
    await tester.tap(find.text('Оформить заказ'));
    await harness.settle(tester, frames: 12);
  }

  PaymentIntent intent(PaymentStatus status, {int amountMinor = 2600}) =>
      PaymentIntent(
        id: 'int_1',
        orderId: 'ord_1',
        status: status,
        amount: byn(amountMinor),
        provider: 'bepaid',
        createdAt: testNow,
        methodId: 'bank_card',
        hostedPageUrl: 'https://pay.example.test/int_1?token=abc',
      );

  testWidgets(
    'после оформления открывается оплата, статус выполнения не меняется',
    (tester) async {
      final port = FakePaymentPort(
        methodsByRegion: <String, List<PaymentMethodInfo>>{
          'BY': <PaymentMethodInfo>[cardMethod(), codMethod()],
        },
        onCreate: (key) async => Ok<PaymentIntent>(
          intent(PaymentStatus.requiresAction, amountMinor: 4711),
        ),
        onStatus: (intentId) async => Ok<PaymentIntent>(
          intent(PaymentStatus.succeeded, amountMinor: 4711),
        ),
      );
      final launcher = FakeLauncher();
      final harness = FunnelHarness(
        extraOverrides: <Override>[
          paymentPortProvider.overrideWithValue(port),
          hostedPageLauncherProvider.overrideWithValue(launcher),
          paymentDelayProvider.overrideWithValue((_) async {}),
        ],
      );
      stubCheckoutData(harness);
      when(
        () => harness.api.checkout(
          any(that: isA<CheckoutRequest>()),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => Ok<Order>(orderFixture()));

      await placeOrder(tester, harness);

      expect(find.text('Заказ PP-1001'), findsOneWidget);
      expect(find.text('Оплата заказа'), findsOneWidget);
      expect(find.text('К оплате 26,00 BYN'), findsOneWidget);
      expect(port.createKeys, isEmpty);

      await tester.tap(find.byKey(const Key('payment-pay')));
      await harness.settle(tester, frames: 12);

      expect(launcher.opened, hasLength(1));
      expect(port.createKeys, hasLength(1));
      expect(port.createKeys.single.isNotEmpty, isTrue);
      expect(find.text('47,11 BYN'), findsOneWidget);
      expect(find.text('Заказ оплачен'), findsOneWidget);
      expect(find.text('Оформлен'), findsOneWidget);
    },
  );

  testWidgets('заказ на 0 BYN (PIC100) не предлагает оплату', (tester) async {
    final port = FakePaymentPort(
      methodsByRegion: <String, List<PaymentMethodInfo>>{
        'BY': <PaymentMethodInfo>[cardMethod()],
      },
      onCreate: (key) async =>
          Ok<PaymentIntent>(intent(PaymentStatus.requiresAction)),
      onStatus: (intentId) async =>
          Ok<PaymentIntent>(intent(PaymentStatus.succeeded)),
    );
    final harness = FunnelHarness(
      extraOverrides: <Override>[
        paymentPortProvider.overrideWithValue(port),
        hostedPageLauncherProvider.overrideWithValue(FakeLauncher()),
        paymentDelayProvider.overrideWithValue((_) async {}),
      ],
    );
    stubCheckoutData(harness);
    when(
      () => harness.api.checkout(
        any(that: isA<CheckoutRequest>()),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer(
      (_) async => Ok<Order>(
        Order(
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
        ),
      ),
    );

    await placeOrder(tester, harness);

    expect(find.text('Заказ PP-1002'), findsOneWidget);
    expect(find.text('Оплата заказа'), findsNothing);
    expect(find.byKey(const Key('payment-pay')), findsNothing);
    expect(port.methodRegions, isEmpty);
  });
}
