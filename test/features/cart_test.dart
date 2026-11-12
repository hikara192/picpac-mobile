import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:picpac_mobile/app/router.dart';
import 'package:picpac_mobile/core/session/guest_work.dart';
import 'package:picpac_mobile/features/auth/presentation/login_page.dart';

import 'support/fixtures.dart';
import 'support/funnel_harness.dart';
import 'support/mock_harness.dart';

void main() {
  setUpAll(registerFunnelFallbacks);

  void stubCartContext(FunnelHarness harness, {Cart? cart}) {
    when(() => harness.api.cart())
        .thenAnswer((_) async => Ok<Cart>(cart ?? cartFixture()));
    when(() => harness.api.catalog())
        .thenAnswer((_) async => Ok<CatalogResponse>(catalogResponse()));
    when(() => harness.api.design('dsg_1'))
        .thenAnswer((_) async => Ok<DesignDto>(printDesignFixture()));
  }

  void stubBookCartContext(FunnelHarness harness, {Cart? cart}) {
    when(() => harness.api.cart())
        .thenAnswer((_) async => Ok<Cart>(cart ?? bookCartFixture()));
    when(() => harness.api.catalog())
        .thenAnswer((_) async => Ok<CatalogResponse>(catalogResponse()));
    when(() => harness.api.design('dsg_book'))
        .thenAnswer((_) async => Ok<DesignDto>(bookDesignFixture()));
  }

  testWidgets('корзина показывает позиции, единицу и сумму из ответа сервера', (
    tester,
  ) async {
    final live = await MockHarness.forWidgetTest(tester);
    final design = await live.setup(
      tester,
      () => live.createPrintDesign(sheets: 3),
    );
    await live.setup(tester, () => live.addToCart(design.id, quantity: 3));

    await live.pump(tester, location: AppRoutes.cart);

    expect(find.text('Печать фотографий 10×15'), findsOneWidget);
    expect(find.text('3 листа'), findsOneWidget);
    expect(find.text('3,90 BYN'), findsNWidgets(2));
    expect(find.text('Готовность через 2 дн.'), findsOneWidget);

    await live.disposeForTest(tester);
  });

  testWidgets('сумма меняется только вместе с ответом сервера', (tester) async {
    final live = await MockHarness.forWidgetTest(tester);
    final design = await live.setup(
      tester,
      () => live.createBookDesign(spreads: 10),
    );
    final cart = await live.setup(tester, () => live.addToCart(design.id));

    await live.pump(tester, location: AppRoutes.cart);

    expect(find.text('Фотокнига Classic 20×20'), findsOneWidget);
    expect(find.text('1 книга · 10 разворотов'), findsOneWidget);
    expect(find.text('81,00 BYN'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Добавить штуку'));
    await live.settle(tester);

    expect(find.text('2'), findsOneWidget);
    expect(find.text('81,00 BYN'), findsNothing);
    expect(find.text('162,00 BYN'), findsNWidgets(2));
    final patches = live.backend.callsTo(
      'PATCH',
      '/v1/cart/items/${cart.items.single.id}',
    );
    expect(
      patches,
      hasLength(1),
      reason: 'one re-price request, not a local sum',
    );
    expect(patches.single.status, 200);

    await live.disposeForTest(tester);
  });

  testWidgets('книга считается разворотами, количество — это тираж', (
    tester,
  ) async {
    final harness = FunnelHarness();
    stubBookCartContext(harness);

    await harness.pump(tester);
    harness.go(AppRoutes.cart);
    await harness.settle(tester);

    expect(find.text('Фотокнига Classic 20×20'), findsOneWidget);
    expect(find.text('1 книга · 10 разворотов'), findsOneWidget);
    expect(find.byTooltip('Добавить штуку'), findsOneWidget);
    expect(find.text('81,00 BYN'), findsNWidgets(2));
  });

  testWidgets('изменение тиража показывает сумму из ответа сервера', (
    tester,
  ) async {
    final harness = FunnelHarness();
    stubBookCartContext(harness);
    when(
      () => harness.api.updateCartItem(any(that: isA<UpdateCartItemRequest>())),
    ).thenAnswer(
      (_) async => Ok<Cart>(bookCartFixture(quantity: 3, subtotal: 24300)),
    );

    await harness.pump(tester);
    harness.go(AppRoutes.cart);
    await harness.settle(tester);

    await tester.tap(find.byTooltip('Добавить штуку'));
    await harness.settle(tester);

    expect(find.text('3'), findsOneWidget);
    expect(find.text('81,00 BYN'), findsNothing);
    expect(find.text('243,00 BYN'), findsNWidgets(2));
    verify(
      () => harness.api.updateCartItem(
        any(
          that: isA<UpdateCartItemRequest>()
              .having((request) => request.itemId, 'itemId', 'cli_book')
              .having((request) => request.quantity, 'quantity', 2),
        ),
      ),
    ).called(1);
  });

  testWidgets('ошибка обновления откатывает количество и объясняет причину', (
    tester,
  ) async {
    final harness = FunnelHarness();
    stubBookCartContext(harness);
    when(
      () => harness.api.updateCartItem(any(that: isA<UpdateCartItemRequest>())),
    ).thenAnswer((_) async => Err<Cart>(ApiFailure.networkUnavailable()));

    await harness.pump(tester);
    harness.go(AppRoutes.cart);
    await harness.settle(tester);

    await tester.tap(find.byTooltip('Добавить штуку'));
    await harness.settle(tester);

    expect(find.text('1'), findsOneWidget);
    expect(find.textContaining('Не удалось обновить корзину'), findsOneWidget);
  });

  testWidgets('степпер объявляет количество для скринридера', (tester) async {
    final semantics = tester.ensureSemantics();
    final harness = FunnelHarness();
    stubBookCartContext(harness);

    await harness.pump(tester);
    harness.go(AppRoutes.cart);
    await harness.settle(tester);

    expect(find.bySemanticsLabel(RegExp('Количество: 1')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('количество листов задаёт макет, а не степпер', (tester) async {
    final harness = FunnelHarness();
    stubCartContext(harness);

    await harness.pump(tester);
    harness.go(AppRoutes.cart);
    await harness.settle(tester);

    expect(find.byTooltip('Добавить штуку'), findsNothing);
    expect(find.text('По макету'), findsOneWidget);
  });

  testWidgets('лист корзины ведёт в свой проект', (tester) async {
    final harness = FunnelHarness();
    stubCartContext(harness);
    when(() => harness.api.preflight(any(), revision: any(named: 'revision')))
        .thenAnswer(
          (_) async =>
              Ok<PreflightDto>(const PreflightDto(revision: 1, canOrder: true)),
        );

    await harness.pump(tester);
    harness.go(AppRoutes.cart);
    await harness.settle(tester);

    await tester.tap(find.byKey(const Key('cart-line-cli_1')));
    await harness.settle(tester);

    expect(find.text('Проверка макета'), findsOneWidget);
  });

  testWidgets('удаление позиции требует подтверждения', (tester) async {
    final harness = FunnelHarness();
    stubCartContext(harness);
    when(() => harness.api.removeCartItem('cli_1')).thenAnswer(
      (_) async => Ok<Cart>(
        Cart(
          id: 'cart_1',
          items: const <CartItem>[],
          expiresAt: DateTime.utc(2026, 11, 25),
          subtotal: byn(0),
        ),
      ),
    );

    await harness.pump(tester);
    harness.go(AppRoutes.cart);
    await harness.settle(tester);

    await tester.tap(find.byTooltip('Удалить'));
    await harness.settle(tester);

    expect(find.text('Удалить позицию?'), findsOneWidget);
    await tester.tap(find.text('Удалить').last);
    await harness.settle(tester);

    expect(find.text('Корзина пуста'), findsOneWidget);
    verify(() => harness.api.removeCartItem('cli_1')).called(1);
  });

  testWidgets('пустая корзина объясняет состояние и ведёт дальше', (
    tester,
  ) async {
    final harness = FunnelHarness();
    stubCartContext(
      harness,
      cart: Cart(
        id: 'cart_1',
        items: const <CartItem>[],
        expiresAt: DateTime.utc(2026, 11, 25),
        subtotal: byn(0),
      ),
    );

    await harness.pump(tester);
    harness.go(AppRoutes.cart);
    await harness.settle(tester);

    expect(find.text('Корзина пуста'), findsOneWidget);
    expect(find.text('В каталог'), findsOneWidget);
    expect(find.byKey(const Key('cart-open-projects')), findsNothing);
  });

  testWidgets('гость перед входом видит честное предупреждение о проекте', (
    tester,
  ) async {
    final harness = FunnelHarness();
    stubCartContext(harness);

    await harness.pump(tester);
    await harness.signIn(UserRole.guest);
    harness.container
        .read(guestWorkProvider.notifier)
        .rememberDesign('dsg_1', role: UserRole.guest);
    harness.go(AppRoutes.cart);
    await harness.settle(tester);

    await tester.tap(find.byKey(const Key('cart-checkout')));
    await harness.settle(tester);

    expect(find.text('Проект собран как гость'), findsOneWidget);
    expect(
      find.textContaining('После входа его нужно будет собрать заново'),
      findsOneWidget,
    );
    expect(
      find.textContaining('перенесём'),
      findsNothing,
      reason: 'нельзя обещать перенос проекта, которого нет',
    );
  });

  testWidgets('без сессии корзина предлагает вход, а не молчит', (
    tester,
  ) async {
    final harness = FunnelHarness(role: UserRole.unknown);
    when(() => harness.api.createAnonymousSession(any())).thenAnswer(
      (_) async => Err<AuthSession>(ApiFailure.networkUnavailable()),
    );
    when(() => harness.api.cart()).thenAnswer(
      (_) async => Err<Cart>(
        const ApiFailure(
          code: ApiErrorCode.unauthorized,
          message: 'unauthorized',
          statusCode: 401,
        ),
      ),
    );

    await harness.pump(tester);
    harness.go(AppRoutes.cart);
    await harness.settle(tester);

    expect(find.text('Войти'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);

    await tester.tap(find.text('Войти'));
    await harness.settle(tester);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byKey(const Key('login-email')), findsOneWidget);

    when(() => harness.api.login(any())).thenAnswer(
      (_) async => Ok<AuthSession>(
        AuthSession(
          token: 'fresh-token',
          role: UserRole.customer,
          customerId: 'cus_demo',
        ),
      ),
    );
    when(() => harness.api.cart())
        .thenAnswer((_) async => Ok<Cart>(cartFixture()));
    when(() => harness.api.catalog())
        .thenAnswer((_) async => Ok<CatalogResponse>(catalogResponse()));
    when(() => harness.api.design('dsg_1'))
        .thenAnswer((_) async => Ok<DesignDto>(printDesignFixture()));

    await tester.enterText(
      find.byKey(const Key('login-email')),
      'customer@picpac.test',
    );
    await tester.enterText(find.byKey(const Key('login-password')), 'Test1234');
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await harness.settle(tester);

    expect(find.byType(LoginPage), findsNothing);
    expect(
      harness.container
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      AppRoutes.cart,
    );
    expect(find.text('Печать фотографий 10×15'), findsOneWidget);
    expect(harness.tokens.session?.role, UserRole.customer);
  });

  testWidgets('корзина всегда оставляет выход: закрыть или назад', (
    tester,
  ) async {
    final live = await MockHarness.forWidgetTest(tester);

    await live.pump(tester, location: AppRoutes.cart);
    expect(find.byKey(const Key('cart-close')), findsOneWidget);
    await tester.tap(find.byKey(const Key('cart-close')));
    await live.settle(tester);
    expect(
      live.container
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      AppRoutes.catalog,
    );

    live.go(AppRoutes.catalog);
    await live.settle(tester);
    live.push(AppRoutes.cart);
    await live.settle(tester);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byKey(const Key('cart-close')), findsNothing);
    await tester.tap(find.byType(BackButton));
    await live.settle(tester);
    expect(
      live.container
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      AppRoutes.catalog,
    );

    await live.disposeForTest(tester);
  });

  testWidgets('проект без фото не создаётся на сервере и не идёт в корзину', (
    tester,
  ) async {
    final live = await MockHarness.forWidgetTest(tester);
    final designId = await live.seedLocalDraft(tester, photos: 0);
    await live.pump(tester, location: AppRoutes.preflightFor(designId));
    await live.settleReal(tester);

    final cta = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'В корзину'),
    );
    expect(cta.onPressed, isNull);

    await tester.tap(find.text('Продолжить всё равно'));
    await live.settle(tester);
    await tester.tap(find.text('Продолжить'));
    await live.settle(tester, frames: 50);
    await tester.tap(find.widgetWithText(FilledButton, 'В корзину'));
    await live.settle(tester);

    expect(
      find.textContaining('Не удалось добавить в корзину'),
      findsOneWidget,
    );
    expect(
      live.container
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      AppRoutes.preflightFor(designId),
    );
    expect(live.backend.callsTo('POST', '/v1/designs'), isEmpty);
    expect(live.backend.callsTo('POST', '/v1/cart/items'), isEmpty);
    expect(live.backend.server.designs, isEmpty);

    await live.disposeForTest(tester);
  });
}
