import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:picpac_mobile/app/router.dart';
import 'package:picpac_mobile/core/orders/demo_controls.dart';

import 'support/fixtures.dart';
import 'support/funnel_harness.dart';
import 'support/mock_harness.dart';

void main() {
  setUpAll(registerFunnelFallbacks);

  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('история и заказ против реального mock-сервера', () {
    testWidgets('история показывает заказ с сервера и открывает его по тапу', (
      tester,
    ) async {
      useTallViewport(tester);
      final live = await MockHarness.forWidgetTest(tester);
      final order = await live.setup(tester, () => live.placeOrder(sheets: 2));

      await live.pump(tester, location: AppRoutes.orders);

      expect(find.text(order.number), findsOneWidget);
      expect(find.text('2,60 BYN'), findsWidgets);
      expect(find.text('Оформлен'), findsOneWidget);

      await tester.tap(find.text(order.number));
      await live.settle(tester);

      expect(find.text('Заказ ${order.number}'), findsOneWidget);
      expect(find.text('Ожидает оплаты'), findsOneWidget);
      expect(find.text('Оформлен'), findsWidgets);
      expect(find.text('Печать фотографий 10×15'), findsOneWidget);
      expect(find.text('Код самовывоза'), findsOneWidget);

      await live.disposeForTest(tester);
    });

    testWidgets('офлайн: история и заказ открываются из кеша с пометкой', (
      tester,
    ) async {
      final live = await MockHarness.forWidgetTest(tester);
      final order = await live.setup(tester, () => live.placeOrder());

      await live.pump(tester, location: AppRoutes.orders);
      expect(find.text(order.number), findsOneWidget);

      live.backend.online = false;
      live.go(AppRoutes.catalog);
      await live.settle(tester);
      live.go(AppRoutes.orders);
      await live.settle(tester);

      expect(find.text(order.number), findsOneWidget);
      expect(find.text('Данные могут быть устаревшими'), findsOneWidget);

      live.go(AppRoutes.orderFor(order.id));
      await live.settle(tester);
      expect(find.text('Заказ ${order.number}'), findsOneWidget);
      expect(find.text('Данные могут быть устаревшими'), findsOneWidget);

      await live.disposeForTest(tester);
    });

    testWidgets('ошибка загрузки объясняется, повтор работает', (tester) async {
      final live = await MockHarness.forWidgetTest(tester);
      live.backend.online = false;

      await live.pump(tester, location: AppRoutes.orders);

      expect(
        find.text('Что-то пошло не так. Попробуйте ещё раз.'),
        findsOneWidget,
      );
      expect(find.text('Повторить'), findsOneWidget);
      expect(find.text('Заказов пока нет'), findsNothing);

      live.backend.online = true;
      await tester.tap(find.text('Повторить'));
      await live.settle(tester);

      expect(find.text('Заказов пока нет'), findsOneWidget);
      expect(live.backend.callsTo('GET', '/v1/orders'), hasLength(1));

      await live.disposeForTest(tester);
    });
  });

  testWidgets('пустая история объясняет состояние', (tester) async {
    final harness = FunnelHarness();
    when(
      () => harness.api.orders(
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
        status: any(named: 'status'),
      ),
    ).thenAnswer(
      (_) async =>
          Ok<OrderHistoryPage>(const OrderHistoryPage(orders: <Order>[])),
    );

    await harness.pump(tester);
    harness.go(AppRoutes.orders);
    await harness.settle(tester);

    expect(find.text('Заказов пока нет'), findsOneWidget);
    expect(find.text('В каталог'), findsOneWidget);
  });

  testWidgets('экран заказа разделяет оплату и готовность, показывает ленту', (
    tester,
  ) async {
    final harness = FunnelHarness();
    final order = orderFixture(
      paymentStatus: PaymentStatus.succeeded,
      fulfillmentStatus: OrderStatus.production,
      history: <OrderStatusEvent>[
        OrderStatusEvent(
          status: OrderStatus.placed,
          at: DateTime.utc(2026, 11, 11, 9),
        ),
        OrderStatusEvent(
          status: OrderStatus.accepted,
          at: DateTime.utc(2026, 11, 11, 10),
        ),
        OrderStatusEvent(
          status: OrderStatus.production,
          at: DateTime.utc(2026, 11, 11, 11),
        ),
      ],
    );
    when(() => harness.api.order('ord_1'))
        .thenAnswer((_) async => Ok<Order>(order));
    when(() => harness.api.pickupPoints()).thenAnswer(
      (_) async => Ok<List<PickupPoint>>(<PickupPoint>[pickupPoint()]),
    );
    when(() => harness.api.deliveryOptions()).thenAnswer(
      (_) async => Ok<List<DeliveryOption>>(<DeliveryOption>[deliveryOption()]),
    );

    await harness.pump(tester);
    harness.push(AppRoutes.orderFor('ord_1'));
    await harness.settle(tester);

    expect(find.text('Заказ PP-1001'), findsOneWidget);
    expect(find.text('Оплата'), findsOneWidget);
    expect(find.text('Готовность'), findsOneWidget);
    expect(find.text('Оплачен'), findsOneWidget);
    expect(find.text('В производстве'), findsWidgets);
    expect(find.text('Код самовывоза'), findsOneWidget);
    expect(find.text('1001'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await harness.settle(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await harness.settle(tester);

    expect(find.text('Принят'), findsOneWidget);
    expect(find.textContaining('11 нояб.'), findsWidgets);
  });

  testWidgets('неизвестный статус отображается как «обновляется»', (
    tester,
  ) async {
    final harness = FunnelHarness();
    final json = orderFixture().toJson()..['fulfillmentStatus'] = 'quantum';
    final unknown = Order.fromJson(json);
    expect(unknown.fulfillmentStatus, OrderStatus.unknown);

    await harness.pump(tester);
    harness.push(AppRoutes.orderFor('ord_1'), extra: unknown);
    await harness.settle(tester);

    expect(find.text('обновляется'), findsOneWidget);
    expect(find.text('Заказ PP-1001'), findsOneWidget);
  });

  testWidgets('неверные данные поиска дают одно понятное сообщение', (
    tester,
  ) async {
    final harness = FunnelHarness(role: UserRole.unknown);
    when(
      () => harness.api.lookupOrder(
        number: any(named: 'number'),
        phoneLast4: any(named: 'phoneLast4'),
      ),
    ).thenAnswer(
      (_) async => Err<Order>(
        const ApiFailure(
          code: ApiErrorCode.notFound,
          message: 'order not found',
          statusCode: 404,
        ),
      ),
    );

    await harness.pump(tester);
    harness.go(AppRoutes.orderLookup);
    await harness.settle(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'PP-9999');
    await tester.enterText(find.byType(TextFormField).at(1), '0000');
    await tester.tap(find.text('Найти'));
    await harness.settle(tester);

    expect(
      find.text('Заказ с таким номером и телефоном не найден'),
      findsOneWidget,
    );
  });

  testWidgets('гостевой поиск открывает заказ без сессии', (tester) async {
    useTallViewport(tester);
    final harness = FunnelHarness(role: UserRole.unknown);
    when(
      () => harness.api.lookupOrder(
        number: any(named: 'number'),
        phoneLast4: any(named: 'phoneLast4'),
      ),
    ).thenAnswer((_) async => Ok<Order>(orderFixture()));
    when(() => harness.api.pickupPoints()).thenAnswer(
      (_) async => Ok<List<PickupPoint>>(<PickupPoint>[pickupPoint()]),
    );
    when(() => harness.api.deliveryOptions()).thenAnswer(
      (_) async => Ok<List<DeliveryOption>>(<DeliveryOption>[deliveryOption()]),
    );

    await harness.pump(tester);
    harness.go(AppRoutes.orderLookup);
    await harness.settle(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'PP-1001');
    await tester.enterText(find.byType(TextFormField).at(1), '1234');
    await tester.tap(find.text('Найти'));
    await harness.settle(tester);

    expect(find.text('Заказ PP-1001'), findsOneWidget);
    expect(find.text('Код самовывоза'), findsOneWidget);
    expect(find.text('Минск, Минский проспект, 32'), findsOneWidget);
  });

  testWidgets('гостю история недоступна: вход вместо пустого списка', (
    tester,
  ) async {
    final harness = FunnelHarness(role: UserRole.unknown);

    await harness.pump(tester);
    harness.go(AppRoutes.orders);
    await harness.settle(tester);

    expect(find.text('Вход в PicPac'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Найти заказ по номеру'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Найти заказ по номеру'), findsOneWidget);
  });

  group('демо-управление статусом: правила ролей на реальном сервере', () {
    testWidgets('клиент: сервер отвечает 403 advance_requires_support', (
      tester,
    ) async {
      useTallViewport(tester);
      final live = await MockHarness.forWidgetTest(tester);
      final order = await live.setup(tester, () => live.placeOrder());

      final attempt = await live.setup(
        tester,
        () => live.demoControls.advance(order.id),
      );
      expect(attempt.isErr, isTrue);
      expect(attempt.failureOrNull?.code, 'advance_requires_support');
      expect(isAdvanceNeedsSupport(attempt.failureOrNull!), isTrue);

      await live.pump(tester, location: AppRoutes.orderFor(order.id));
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await live.settle(tester);

      expect(find.byKey(const Key('order-demo-advance')), findsNothing);
      expect(find.text('Управление статусом'), findsNothing);
      final after = await live.setup(tester, () => live.api.order(order.id));
      expect(after.requireValue.fulfillmentStatus, OrderStatus.placed);

      await live.disposeForTest(tester);
    });

    testWidgets('поддержка двигает готовность; оплата — отдельная ось', (
      tester,
    ) async {
      final backend = MockBackend();
      final customer = await MockHarness.forWidgetTest(
        tester,
        backend: backend,
      );
      final order = await customer.setup(tester, () => customer.placeOrder());
      await customer.disposeForTest(tester);

      final support = await MockHarness.forWidgetTest(
        tester,
        role: UserRole.supportAgent,
        backend: backend,
      );
      final advanced = await support.setup(
        tester,
        () => support.demoControls.advance(order.id),
      );
      expect(advanced.isOk, isTrue, reason: '${advanced.failureOrNull}');
      expect(advanced.requireValue.fulfillmentStatus, OrderStatus.accepted);
      expect(advanced.requireValue.paymentStatus.isPaid, isFalse);

      final payer = await MockHarness.forWidgetTest(tester, backend: backend);
      final created = await payer.setup(
        tester,
        () => payer.api.createPaymentIntent(
          CreatePaymentIntentRequest(orderId: order.id, methodId: 'bank_card'),
          idempotencyKey: 'demo-intent-${order.id}',
        ),
      );
      expect(created.isOk, isTrue, reason: '${created.failureOrNull}');
      final hosted = created.requireValue.hostedPageUrl;
      expect(hosted, isNotNull);

      final confirmed = await payer.setup(
        tester,
        () => payer.demoControls.confirmHostedPayment(Uri.parse(hosted!)),
      );
      expect(confirmed.isOk, isTrue, reason: '${confirmed.failureOrNull}');
      final verified = await payer.setup(
        tester,
        () => payer.api.paymentIntent(created.requireValue.id),
      );
      expect(verified.requireValue.status, PaymentStatus.succeeded);
      final paid = await payer.setup(tester, () => payer.api.order(order.id));
      expect(paid.requireValue.paymentStatus.isPaid, isTrue);
      expect(paid.requireValue.fulfillmentStatus, OrderStatus.accepted);

      await support.disposeForTest(tester);
      await payer.disposeForTest(tester);
    });

    testWidgets('BFF без /mock отвечает 404: блок скрывается, а не падает', (
      tester,
    ) async {
      final backend = MockBackend(mockControls: false);
      final live = await MockHarness.forWidgetTest(
        tester,
        role: UserRole.supportAgent,
        backend: backend,
      );
      final attempt = await live.setup(
        tester,
        () => live.demoControls.advance('ord_missing'),
      );
      expect(attempt.isErr, isTrue);
      expect(isDemoEndpointUnavailable(attempt.failureOrNull!), isTrue);

      await live.disposeForTest(tester);
    });
  });
}
