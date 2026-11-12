import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:picpac_mobile/app/router.dart';
import 'package:picpac_mobile/app/theme/tokens.dart';

import '../features/support/design_fixtures.dart';
import '../features/support/design_harness.dart';
import '../features/support/fixtures.dart';
import '../features/support/funnel_harness.dart';

void main() {
  setUpAll(() {
    registerFunnelFallbacks();
    registerDesignFallbacks();
  });

  void useSmallScaledViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Future<void> scrollThrough(
    WidgetTester tester, {
    int steps = 5,
    Finder? scrollable,
  }) async {
    final target = scrollable ?? find.byType(Scrollable).first;
    for (var i = 0; i < steps; i++) {
      if (target.evaluate().isEmpty) return;
      await tester.drag(target, const Offset(0, -240));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.takeException(),
        isNull,
        reason: 'overflow после прокрутки $i',
      );
    }
  }

  Future<void> stubShell(FunnelHarness harness) async {
    when(() => harness.api.catalog())
        .thenAnswer((_) async => Ok<CatalogResponse>(catalogResponse()));
  }

  testWidgets('каталог: 320×640 при textScaler 2.0 без переполнений', (
    tester,
  ) async {
    useSmallScaledViewport(tester);
    final harness = FunnelHarness();
    await stubShell(harness);

    await harness.pump(tester);
    harness.go(AppRoutes.catalog);
    await harness.settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Фотокнига Classic'), findsOneWidget);
    await scrollThrough(tester, steps: 3);
  });

  testWidgets('корзина: 320×640 при textScaler 2.0 без переполнений', (
    tester,
  ) async {
    useSmallScaledViewport(tester);
    final harness = FunnelHarness();
    await stubShell(harness);
    when(() => harness.api.cart())
        .thenAnswer((_) async => Ok<Cart>(cartFixture()));
    when(() => harness.api.design('dsg_1'))
        .thenAnswer((_) async => Ok<DesignDto>(printDesignFixture()));

    await harness.pump(tester);
    harness.go(AppRoutes.cart);
    await harness.settle(tester);

    expect(tester.takeException(), isNull);
    final checkout = find.byKey(const Key('cart-checkout'));
    expect(
      tester.getSize(checkout).height,
      greaterThanOrEqualTo(kMinTouchTarget),
    );
    await scrollThrough(tester, steps: 3);
  });

  testWidgets('чекаут: 320×640 при textScaler 2.0 без переполнений', (
    tester,
  ) async {
    useSmallScaledViewport(tester);
    final harness = FunnelHarness();
    await stubShell(harness);
    when(() => harness.api.cart()).thenAnswer(
      (_) async => Ok<Cart>(cartFixture(quantity: 1, subtotal: 1300)),
    );
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
    when(() => harness.api.price(any()))
        .thenAnswer((_) async => Ok<PriceQuote>(priceQuote(total: 1300)));

    await harness.pump(tester);
    harness.go(AppRoutes.checkout);
    await harness.settle(tester);

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(const Key('checkout-name')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await scrollThrough(tester, steps: 6);
  });

  testWidgets('заказ: 320×640 при textScaler 2.0 без переполнений', (
    tester,
  ) async {
    useSmallScaledViewport(tester);
    final harness = FunnelHarness();
    await stubShell(harness);
    when(() => harness.api.order('ord_1'))
        .thenAnswer((_) async => Ok<Order>(orderFixture()));
    when(() => harness.api.pickupPoints()).thenAnswer(
      (_) async => Ok<List<PickupPoint>>(<PickupPoint>[pickupPoint()]),
    );
    when(() => harness.api.deliveryOptions()).thenAnswer(
      (_) async => Ok<List<DeliveryOption>>(<DeliveryOption>[deliveryOption()]),
    );

    await harness.pump(tester);
    harness.push(AppRoutes.orderFor('ord_1'));
    await harness.settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Заказ PP-1001'), findsOneWidget);
    expect(find.text('Оформлен'), findsWidgets);
    await scrollThrough(tester, steps: 8);
  });

  testWidgets('поддержка: 320×640 при textScaler 2.0 без переполнений', (
    tester,
  ) async {
    useSmallScaledViewport(tester);
    final harness = FunnelHarness();
    await stubShell(harness);
    when(() => harness.api.supportTickets()).thenAnswer(
      (_) async => Ok<List<SupportTicket>>(<SupportTicket>[
        supportTicketFixture(subject: 'Фото с полосой'),
        supportTicketFixture(
          id: 'tkt_2',
          subject: 'Не пришёл заказ',
          status: TicketStatus.resolved,
          type: TicketType.delivery,
        ),
      ]),
    );

    await harness.pump(tester);
    harness.go(AppRoutes.support);
    await harness.settle(tester);

    expect(tester.takeException(), isNull);
    await scrollThrough(tester, steps: 3);
  });

  testWidgets('профиль: 320×640 при textScaler 2.0 без переполнений', (
    tester,
  ) async {
    useSmallScaledViewport(tester);
    final harness = FunnelHarness();
    await stubShell(harness);
    when(() => harness.api.currentCustomer()).thenAnswer(
      (_) async => Ok<Customer>(
        Customer(
          id: 'cus_demo',
          createdAt: testNow,
          name: 'Тестовый клиент',
          email: 'customer@picpac.test',
          phoneMasked: '+375 ** *** 12 34',
        ),
      ),
    );

    await harness.pump(tester);
    harness.go(AppRoutes.profile);
    await harness.settle(tester);

    expect(tester.takeException(), isNull);
    await scrollThrough(tester, steps: 8);
  });

  testWidgets('редактор: 320×640 при textScaler 2.0 без переполнений', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 2);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester, location: '/editor/dsg_1');
    expect(tester.takeException(), isNull);

    for (final tool in <String>[
      'frame',
      'light',
      'warmth',
      'style',
      'replace',
      'background',
    ]) {
      final target = find.byKey(ValueKey<String>('editor_tool_$tool'));
      expect(target, findsWidgets, reason: '$tool exists');
      await tester.ensureVisible(target.first);
      await tester.pump();
      await tester.tap(target.first);
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull, reason: 'панель «$tool»');
    }

    final tool = find.byKey(const ValueKey<String>('editor_tool_light'));
    expect(tester.getSize(tool).height, greaterThanOrEqualTo(kMinTouchTarget));

    await tester.pump(const Duration(milliseconds: 300));
    await harness.settleReal(tester, frames: 4);
    await harness.disposeForTest(tester);
  });
}
