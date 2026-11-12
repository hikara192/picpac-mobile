import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:picpac_mobile/app/router.dart';
import 'package:picpac_mobile/features/auth/presentation/login_page.dart';
import 'package:picpac_mobile/features/checkout/presentation/checkout_page.dart';

import '../support/fixtures.dart';
import '../support/funnel_harness.dart';
import '../support/mock_harness.dart';

void main() {
  setUpAll(registerFunnelFallbacks);

  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  AuthSession sessionFor(UserRole role, {String token = 'test-token'}) =>
      AuthSession(
        token: token,
        role: role,
        customerId: role == UserRole.supportAgent ? 'sup_demo' : 'cus_demo',
        customer: Customer(
          id: role == UserRole.supportAgent ? 'sup_demo' : 'cus_demo',
          createdAt: testNow,
          name: role == UserRole.supportAgent
              ? 'Агент поддержки'
              : 'Тестовый клиент',
          email: role == UserRole.supportAgent
              ? 'support@picpac.test'
              : 'customer@picpac.test',
          isGuest: false,
        ),
      );

  void stubEmptyCart(FunnelHarness harness) {
    when(() => harness.api.cart()).thenAnswer(
      (_) async => Ok<Cart>(
        Cart(
          id: 'cart_1',
          items: const <CartItem>[],
          expiresAt: DateTime.utc(2026, 11, 25),
          subtotal: byn(0),
          canCheckout: false,
        ),
      ),
    );
    when(() => harness.api.catalog())
        .thenAnswer((_) async => Ok<CatalogResponse>(catalogResponse()));
    when(() => harness.api.deliveryOptions())
        .thenAnswer((_) async => Ok<List<DeliveryOption>>(<DeliveryOption>[]));
    when(() => harness.api.pickupPoints())
        .thenAnswer((_) async => Ok<List<PickupPoint>>(<PickupPoint>[]));
  }

  Future<void> fillCredentials(
    WidgetTester tester, {
    String email = 'customer@picpac.test',
    String password = 'Test1234',
  }) async {
    await tester.enterText(find.byKey(const Key('login-email')), email);
    await tester.enterText(find.byKey(const Key('login-password')), password);
    await tester.pump();
  }

  testWidgets('гость на чекауте попадает на вход и возвращается после входа', (
    tester,
  ) async {
    useTallViewport(tester);
    final harness = FunnelHarness(role: UserRole.unknown);
    stubEmptyCart(harness);
    when(
      () => harness.api.login(any()),
    ).thenAnswer((_) async => Ok<AuthSession>(sessionFor(UserRole.customer)));

    await harness.pump(tester);
    harness.go(AppRoutes.checkout);
    await harness.settle(tester);

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byKey(const Key('login-email')), findsOneWidget);

    await fillCredentials(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await harness.settle(tester);

    expect(find.byType(CheckoutPage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);

    final stored = harness.tokens.session;
    expect(
      stored,
      isNotNull,
      reason: 'токен должен лежать в защищённом хранилище',
    );
    expect(stored!.role, UserRole.customer);
    expect(
      harness.container
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      AppRoutes.checkout,
    );
  });

  testWidgets(
    'неверный пароль даёт нейтральное сообщение без раскрытия аккаунта',
    (tester) async {
      useTallViewport(tester);
      final harness = FunnelHarness(role: UserRole.unknown);
      when(() => harness.api.login(any())).thenAnswer(
        (_) async => Err<AuthSession>(
          const ApiFailure(
            code: ApiErrorCode.unauthorized,
            message: 'invalid email or password',
            statusCode: 401,
          ),
        ),
      );

      await harness.pump(tester);
      harness.go(AppRoutes.login);
      await harness.settle(tester);

      await fillCredentials(tester, password: 'wrong-password');
      await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
      await harness.settle(tester);

      expect(find.text('Неверный email или пароль'), findsOneWidget);
      expect(find.textContaining('не существует'), findsNothing);
      expect(harness.tokens.session, isNull);
      expect(find.byType(LoginPage), findsOneWidget);
    },
  );

  testWidgets('вход по демо-коду 0000 создаёт сессию клиента', (tester) async {
    useTallViewport(tester);
    final harness = FunnelHarness(role: UserRole.unknown);
    when(
      () => harness.api.verifyCode(
        challengeId: any(named: 'challengeId'),
        code: any(named: 'code'),
      ),
    ).thenAnswer((_) async => Ok<AuthSession>(sessionFor(UserRole.customer)));

    await harness.pump(tester);
    harness.go(AppRoutes.login);
    await harness.settle(tester);

    await tester.tap(find.text('По коду'));
    await harness.settle(tester);
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'customer@picpac.test',
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Получить код'));
    await harness.settle(tester);

    expect(find.text('Демо-код: 0000'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('login-code')), '0000');
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await harness.settle(tester);

    verify(
      () => harness.api.verifyCode(challengeId: 'challenge_demo', code: '0000'),
    ).called(1);
    expect(harness.tokens.session?.role, UserRole.customer);
    expect(harness.tokens.session?.token, 'test-token');
  });

  testWidgets(
    'агент поддержки попадает в режим поддержки без клиентских вкладок',
    (tester) async {
      useTallViewport(tester);
      final harness = FunnelHarness(role: UserRole.unknown);
      when(() => harness.api.login(any())).thenAnswer(
        (_) async => Ok<AuthSession>(sessionFor(UserRole.supportAgent)),
      );
      when(() => harness.api.supportTickets()).thenAnswer(
        (_) async => Ok<List<SupportTicket>>(<SupportTicket>[
          supportTicketFixture(id: 'tkt_1', subject: 'Не пришёл заказ'),
          supportTicketFixture(id: 'tkt_2', subject: 'Перепечатка фото'),
        ]),
      );

      await harness.pump(tester);
      harness.go(AppRoutes.login);
      await harness.settle(tester);

      await fillCredentials(tester, email: 'support@picpac.test');
      await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
      await harness.settle(tester);

      expect(harness.tokens.session?.role, UserRole.supportAgent);
      expect(find.text('Режим поддержки'), findsWidgets);
      expect(find.text('Не пришёл заказ'), findsOneWidget);
      expect(find.text('Перепечатка фото'), findsOneWidget);
      expect(find.text('Заказы'), findsNothing);
      expect(find.text('Каталог'), findsNothing);
    },
  );

  testWidgets('выход очищает токен и возвращает гостя', (tester) async {
    useTallViewport(tester);
    final harness = FunnelHarness();
    when(() => harness.api.createAnonymousSession(any())).thenAnswer(
      (_) async => Ok<AuthSession>(
        const AuthSession(token: 'guest-token', role: UserRole.guest),
      ),
    );
    when(() => harness.api.currentCustomer()).thenAnswer(
      (_) async => Ok<Customer>(
        Customer(
          id: 'cus_demo',
          createdAt: testNow,
          name: 'Тестовый клиент',
          email: 'customer@picpac.test',
        ),
      ),
    );

    await harness.pump(tester);
    harness.go(AppRoutes.profile);
    await harness.settle(tester);

    await tester.scrollUntilVisible(
      find.text('Выйти'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Выйти'));
    await harness.settle(tester);
    await tester.tap(find.text('Выйти из аккаунта'));
    await harness.settle(tester);

    expect(harness.tokens.session?.role ?? UserRole.guest, UserRole.guest);
    expect(harness.tokens.session?.token, isNot('test-token'));
    expect(
      harness.container
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      AppRoutes.catalog,
    );
  });

  testWidgets(
    'мёртвый токен: сервер 401 открывает форму, вход возвращает назад',
    (tester) async {
      useTallViewport(tester);
      final live = await MockHarness.forWidgetTest(tester);
      expect(live.tokens.session, isNotNull, reason: 'токен есть до запроса');

      live.backend.restart();

      await live.pump(tester, location: AppRoutes.orders);
      await live.settle(tester, frames: 12);

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byKey(const Key('login-email')), findsOneWidget);
      expect(find.textContaining('Что-то пошло не так'), findsNothing);

      await fillCredentials(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
      await live.settle(tester, frames: 12);

      expect(find.byType(LoginPage), findsNothing);
      expect(
        live.container
            .read(routerProvider)
            .routerDelegate
            .currentConfiguration
            .uri
            .path,
        AppRoutes.orders,
      );
      expect(find.text('Заказов пока нет'), findsOneWidget);
      expect(live.tokens.session?.role, UserRole.customer);

      await live.disposeForTest(tester);
    },
  );
}
