import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:picpac_mobile/app/router.dart';

import 'support/fixtures.dart';
import 'support/funnel_harness.dart';

void main() {
  setUpAll(registerFunnelFallbacks);

  void stubCheckoutData(
    FunnelHarness harness, {
    Cart? cart,
    PriceQuote? quote,
  }) {
    when(() => harness.api.cart()).thenAnswer(
      (_) async => Ok<Cart>(cart ?? cartFixture(quantity: 1, subtotal: 1300)),
    );
    when(() => harness.api.catalog())
        .thenAnswer((_) async => Ok<CatalogResponse>(catalogResponse()));
    when(() => harness.api.design('dsg_1'))
        .thenAnswer((_) async => Ok<DesignDto>(designFixture()));
    when(() => harness.api.deliveryOptions()).thenAnswer(
      (_) async => Ok<List<DeliveryOption>>(<DeliveryOption>[
        deliveryOption(price: 0),
        deliveryOption(
          id: 'europochta',
          kind: DeliveryKind.post,
          titleKey: 'delivery.europochta',
          price: 590,
          etaDays: 2,
          requiresPoint: false,
          freeFrom: 15000,
        ),
      ]),
    );
    when(() => harness.api.pickupPoints()).thenAnswer(
      (_) async => Ok<List<PickupPoint>>(<PickupPoint>[pickupPoint()]),
    );
    when(
      () => harness.api.price(any()),
    ).thenAnswer((_) async => Ok<PriceQuote>(quote ?? priceQuote(total: 1300)));
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

  Future<void> openCheckout(WidgetTester tester, FunnelHarness harness) async {
    await harness.pump(tester);
    harness.go(AppRoutes.checkout);
    await harness.settle(tester);
  }

  Future<void> fillContact(WidgetTester tester, FunnelHarness harness) async {
    await tester.scrollUntilVisible(
      find.byKey(const Key('checkout-name')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await harness.settle(tester);
    await tester.enterText(
      find.byKey(const Key('checkout-name')),
      'Тест Клиент',
    );
    await tester.enterText(
      find.byKey(const Key('checkout-phone')),
      '+375 29 123 45 67',
    );
    await tester.pump();
  }

  testWidgets('чекаут показывает способы получения и итог с сервера', (
    tester,
  ) async {
    final harness = FunnelHarness();
    stubCheckoutData(harness);

    await openCheckout(tester, harness);

    expect(find.text('Самовывоз'), findsOneWidget);
    expect(find.text('Европочта'), findsOneWidget);
    expect(find.textContaining('бесплатно от 150,00 BYN'), findsOneWidget);
    expect(find.text('PicPac на Минском'), findsOneWidget);
    expect(find.text('13,00 BYN'), findsWidgets);
    expect(find.text('Оформить заказ'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await harness.settle(tester);
    expect(find.text('Товары'), findsOneWidget);
    expect(find.text('Итого'), findsOneWidget);
  });

  testWidgets(
    'успешный чекаут ведёт на экран заказа с номером и суммой сервера',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = FunnelHarness();
      stubCheckoutData(harness);
      when(
        () => harness.api.checkout(
          any(that: isA<CheckoutRequest>()),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async =>
            Ok<Order>(orderFixture(number: 'PP-7777', totalMinor: 4711)),
      );

      await openCheckout(tester, harness);
      await fillContact(tester, harness);

      await tester.tap(find.text('Оформить заказ'));
      await harness.settle(tester);

      expect(find.text('Заказ PP-7777'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
      await harness.settle(tester);
      expect(find.text('47,11 BYN'), findsWidgets);
      expect(find.text('13,00 BYN'), findsNothing);
      expect(find.text('Код самовывоза'), findsOneWidget);
      expect(find.text('1001'), findsOneWidget);

      final captured = verify(
        () => harness.api.checkout(
          captureAny(),
          idempotencyKey: captureAny(named: 'idempotencyKey'),
        ),
      ).captured;
      final request = captured[0] as CheckoutRequest;
      expect(request.cartId, 'cart_1');
      expect(request.contact.name, 'Тест Клиент');
      expect(request.contact.phone, '+375291234567');
      expect(request.delivery.kind, DeliveryKind.pickup);
      expect(request.delivery.pointId, 'main');
      expect(request.delivery.slot, isNotNull);
      expect((captured[1] as String).isNotEmpty, isTrue);
    },
  );

  testWidgets('двойной тап по кнопке не создаёт второй заказ', (tester) async {
    final harness = FunnelHarness();
    stubCheckoutData(harness);
    when(
      () => harness.api.checkout(
        any(that: isA<CheckoutRequest>()),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((_) async => Ok<Order>(orderFixture()));

    await openCheckout(tester, harness);
    await fillContact(tester, harness);

    final button = find.text('Оформить заказ');
    await tester.tap(button);
    await tester.tap(button, warnIfMissed: false);
    await harness.settle(tester);

    final keys = verify(
      () => harness.api.checkout(
        any(that: isA<CheckoutRequest>()),
        idempotencyKey: captureAny(named: 'idempotencyKey'),
      ),
    ).captured;
    expect(keys, hasLength(1), reason: 'двойной тап — один заказ');
    expect((keys.single as String).isNotEmpty, isTrue);
  });

  testWidgets('повтор после сетевой ошибки берёт тот же Idempotency-Key', (
    tester,
  ) async {
    final harness = FunnelHarness();
    stubCheckoutData(harness);
    var attempt = 0;
    when(
      () => harness.api.checkout(
        any(that: isA<CheckoutRequest>()),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((_) async {
      attempt++;
      if (attempt == 1) {
        return Err<Order>(ApiFailure.networkUnavailable());
      }
      return Ok<Order>(orderFixture());
    });

    await openCheckout(tester, harness);
    await fillContact(tester, harness);

    await tester.tap(find.text('Оформить заказ'));
    await harness.settle(tester);
    expect(find.textContaining('Нет соединения'), findsOneWidget);
    expect(find.byKey(const Key('checkout-name')), findsOneWidget);

    await tester.tap(find.text('Оформить заказ'));
    await harness.settle(tester);
    expect(find.text('Заказ PP-1001'), findsOneWidget);

    final keys = verify(
      () => harness.api.checkout(
        any(that: isA<CheckoutRequest>()),
        idempotencyKey: captureAny(named: 'idempotencyKey'),
      ),
    ).captured.cast<String>();
    expect(keys, hasLength(2));
    expect(
      keys.first,
      keys.last,
      reason: 'повтор того же оформления обязан переиспользовать ключ',
    );
  });

  testWidgets('конфликт идемпотентности объясняет, что заказ уже создан', (
    tester,
  ) async {
    final harness = FunnelHarness();
    stubCheckoutData(harness);
    when(
      () => harness.api.checkout(
        any(that: isA<CheckoutRequest>()),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer(
      (_) async => Err<Order>(
        const ApiFailure(
          code: ApiErrorCode.idempotencyConflict,
          message: 'same key, different body',
          statusCode: 422,
        ),
      ),
    );

    await openCheckout(tester, harness);
    await fillContact(tester, harness);

    await tester.tap(find.text('Оформить заказ'));
    await harness.settle(tester);

    expect(
      find.textContaining('Заказ уже создан. Откройте историю заказов.'),
      findsOneWidget,
    );
  });

  testWidgets('неизвестный промокод показывается текстом, а не молчит', (
    tester,
  ) async {
    final harness = FunnelHarness();
    stubCheckoutData(harness);
    when(
      () => harness.api.updateCartItem(any(that: isA<UpdateCartItemRequest>())),
    ).thenAnswer(
      (_) async => Err<Cart>(
        const ApiFailure(
          code: 'promo_unknown',
          message: 'the promo code is unknown or expired',
          statusCode: 422,
        ),
      ),
    );

    await openCheckout(tester, harness);

    await tester.scrollUntilVisible(
      find.byKey(const Key('checkout-promo')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await harness.settle(tester);
    await tester.enterText(find.byKey(const Key('checkout-promo')), 'NOPE');
    await tester.tap(find.text('Применить'));
    await harness.settle(tester);

    expect(find.text('Такого промокода нет или он истёк'), findsOneWidget);
  });

  testWidgets(
    'подтверждение preflight даёт оформить заказ (override не тупик)',
    (tester) async {
      final harness = FunnelHarness();
      stubCheckoutData(harness);
      when(() => harness.api.preflight(any(), revision: any(named: 'revision')))
          .thenAnswer(
            (_) async => Ok<PreflightDto>(
              const PreflightDto(
                revision: 1,
                canOrder: false,
                issues: <PreflightIssue>[
                  PreflightIssue(
                    code: PreflightCode.emptySlot,
                    severity: PreflightSeverity.error,
                    targetId: 'main',
                    messageKey: 'preflight.emptySlot',
                    spreadId: 'sheet_1',
                    slotId: 'main',
                  ),
                ],
              ),
            ),
          );
      when(
        () => harness.api.checkout(
          any(that: isA<CheckoutRequest>()),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => Ok<Order>(orderFixture()));

      await openCheckout(tester, harness);
      await fillContact(tester, harness);
      await tester.tap(find.text('Оформить заказ'));
      await harness.settle(tester);

      expect(find.text('Заказ заблокирован проверкой'), findsOneWidget);
      expect(find.textContaining('Добавьте фото'), findsOneWidget);

      await tester.tap(find.text('Продолжить всё равно'));
      await harness.settle(tester);

      expect(find.text('Заказ PP-1001'), findsOneWidget);
      verify(
        () => harness.api.checkout(
          any(that: isA<CheckoutRequest>()),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).called(1);
    },
  );

  testWidgets('422 preflight_blocked объясняет причину и ведёт к проверке', (
    tester,
  ) async {
    final harness = FunnelHarness();
    stubCheckoutData(harness);
    when(() => harness.api.preflight(any(), revision: any(named: 'revision')))
        .thenAnswer(
          (_) async =>
              Ok<PreflightDto>(const PreflightDto(revision: 1, canOrder: true)),
        );
    when(
      () => harness.api.checkout(
        any(that: isA<CheckoutRequest>()),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer(
      (_) async => Err<Order>(
        const ApiFailure(
          code: 'preflight_blocked',
          message: 'the design has blocking preflight issues',
          statusCode: 422,
          fieldErrors: <String, String>{'lines.dsg_1': 'preflight_blocked'},
        ),
      ),
    );

    await openCheckout(tester, harness);
    await fillContact(tester, harness);
    await tester.tap(find.text('Оформить заказ'));
    await harness.settle(tester);

    expect(
      find.text(
        'Заказ нельзя оформить, пока не исправлены замечания проверки макета.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Проверьте введённые данные'), findsNothing);
    expect(find.byKey(const Key('checkout-fix-preflight')), findsOneWidget);
  });

  testWidgets('гостю чекаут недоступен: редирект на вход с возвратом', (
    tester,
  ) async {
    final harness = FunnelHarness(role: UserRole.guest);
    stubCheckoutData(harness);

    await openCheckout(tester, harness);

    expect(find.text('Вход в PicPac'), findsOneWidget);
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(find.text('Оформить заказ'), findsNothing);
  });
}
