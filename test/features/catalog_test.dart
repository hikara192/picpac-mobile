import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:picpac_mobile/app/router.dart';
import 'package:picpac_mobile/features/create/presentation/create_page.dart';

import 'support/fixtures.dart';
import 'support/funnel_harness.dart';

void main() {
  setUpAll(registerFunnelFallbacks);

  testWidgets('каталог рендерит продукты и цены из ответа сервера', (
    tester,
  ) async {
    final harness = FunnelHarness();
    when(() => harness.api.catalog()).thenAnswer(
      (_) async => Ok<CatalogResponse>(
        catalogResponse(
          products: <Product>[
            printProduct(minPrice: byn(555)),
            bookProduct(minPrice: byn(8100)),
          ],
        ),
      ),
    );

    await harness.pump(tester);

    expect(find.text('Печать фотографий'), findsOneWidget);
    expect(find.text('Фотокнига Classic'), findsOneWidget);
    expect(find.text('от 5,55 BYN'), findsOneWidget);
    expect(find.text('от 81,00 BYN'), findsOneWidget);
  });

  testWidgets('ошибка сети показывает сообщение и кнопку «Повторить»', (
    tester,
  ) async {
    final harness = FunnelHarness();
    var calls = 0;
    when(() => harness.api.catalog()).thenAnswer((_) async {
      calls++;
      return calls == 1
          ? Err<CatalogResponse>(ApiFailure.networkUnavailable())
          : Ok<CatalogResponse>(catalogResponse());
    });

    await harness.pump(tester);

    expect(
      find.text('Нет соединения. Проверьте сеть и попробуйте снова.'),
      findsOneWidget,
    );
    expect(find.text('Печать фотографий'), findsNothing);

    await tester.tap(find.text('Повторить'));
    await harness.settle(tester);

    expect(calls, 2);
    expect(find.text('Печать фотографий'), findsOneWidget);
  });

  testWidgets('пустой каталог объясняет состояние и предлагает повторить', (
    tester,
  ) async {
    final harness = FunnelHarness();
    when(() => harness.api.catalog()).thenAnswer(
      (_) async =>
          Ok<CatalogResponse>(catalogResponse(products: const <Product>[])),
    );

    await harness.pump(tester);

    expect(find.text('Каталог пока пуст'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
  });

  testWidgets('карточка продукта берёт форматы и цену из API, «Собрать» '
      'открывает проект локально без сервера', (tester) async {
    final harness = FunnelHarness();
    when(() => harness.api.product('photo_print'))
        .thenAnswer((_) async => Ok<Product>(printProduct()));
    when(() => harness.api.price(any()))
        .thenAnswer((_) async => Ok<PriceQuote>(priceQuote(total: 130)));

    await harness.pump(tester);
    harness.go(AppRoutes.productFor('photo_print'));
    await harness.settle(tester);

    expect(find.text('Форматы и цены'), findsOneWidget);
    expect(find.text('102 × 152 мм'), findsOneWidget);
    expect(find.text('1,30 BYN'), findsOneWidget);

    await tester.tap(find.text('Собрать · 1,30 BYN'));
    await harness.settle(tester);

    final page = tester.widget<CreatePage>(find.byType(CreatePage));
    expect(page.designId, startsWith('local_'));
    verifyNever(() => harness.api.createDesign(any()));
  });

  testWidgets('«Собрать» работает без сессии: проект открывается локально', (
    tester,
  ) async {
    final harness = FunnelHarness(role: UserRole.unknown);
    when(() => harness.api.product('photo_print'))
        .thenAnswer((_) async => Ok<Product>(printProduct()));
    when(() => harness.api.price(any()))
        .thenAnswer((_) async => Ok<PriceQuote>(priceQuote(total: 130)));

    await harness.pump(tester);
    harness.go(AppRoutes.productFor('photo_print'));
    await harness.settle(tester);

    await tester.tap(find.text('Собрать · 1,30 BYN'));
    await harness.settle(tester);

    final page = tester.widget<CreatePage>(find.byType(CreatePage));
    expect(page.designId, startsWith('local_'));
    expect(find.text('Не удалось создать проект'), findsNothing);
  });

  testWidgets('битый сохранённый токен не превращает каталог в «нужно войти»', (
    tester,
  ) async {
    final harness = FunnelHarness();
    var calls = 0;
    when(() => harness.api.catalog()).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        return Err<CatalogResponse>(
          const ApiFailure(
            code: ApiErrorCode.unauthorized,
            message: 'unauthorized',
            statusCode: 401,
          ),
        );
      }
      return Ok<CatalogResponse>(catalogResponse());
    });
    when(() => harness.api.createAnonymousSession(any())).thenAnswer(
      (_) async =>
          Ok<AuthSession>(AuthSession(token: 'guest-2', role: UserRole.guest)),
    );

    await harness.pump(tester);

    expect(find.text('Печать фотографий'), findsOneWidget);
    expect(
      find.text('Нужно войти в аккаунт. Войдите и повторите.'),
      findsNothing,
    );
    expect(calls, 2, reason: 'ровно один повтор после обновления гостя');
    verify(() => harness.api.createAnonymousSession(any())).called(1);
    expect(harness.tokens.session?.token, 'guest-2');
  });

  testWidgets('продукт тоже переживает мёртвый токен', (tester) async {
    final harness = FunnelHarness();
    var calls = 0;
    when(() => harness.api.product('photo_print')).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        return Err<Product>(
          const ApiFailure(
            code: ApiErrorCode.unauthorized,
            message: 'unauthorized',
            statusCode: 401,
          ),
        );
      }
      return Ok<Product>(printProduct());
    });
    when(() => harness.api.price(any()))
        .thenAnswer((_) async => Ok<PriceQuote>(priceQuote(total: 130)));
    when(() => harness.api.createAnonymousSession(any())).thenAnswer(
      (_) async =>
          Ok<AuthSession>(AuthSession(token: 'guest-3', role: UserRole.guest)),
    );

    await harness.pump(tester);
    harness.go(AppRoutes.productFor('photo_print'));
    await harness.settle(tester);

    expect(find.text('Форматы и цены'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('опции формата выбираются и пересчитываются сервером', (
    tester,
  ) async {
    final harness = FunnelHarness();
    final format = ProductFormat(
      id: '10x15',
      productId: 'photo_print',
      title: '10×15',
      widthMm: 102,
      heightMm: 152,
      dpi: 300,
      minPhotos: 1,
      maxPhotos: 4,
      etaDays: 2,
      options: const <ProductOption>[
        ProductOption(
          id: 'paper',
          title: 'Тип бумаги',
          values: <OptionValue>[
            OptionValue(id: 'gloss', title: 'Глянцевая', isDefault: true),
            OptionValue(
              id: 'matte',
              title: 'Матовая',
              priceDeltaMinor: 50,
              currency: 'BYN',
            ),
          ],
        ),
      ],
    );
    when(() => harness.api.product('photo_print')).thenAnswer(
      (_) async => Ok<Product>(
        Product(
          id: 'photo_print',
          title: 'Печать фотографий',
          category: 'prints',
          currency: 'BYN',
          formats: <ProductFormat>[format],
        ),
      ),
    );
    when(() => harness.api.price(any())).thenAnswer((invocation) async {
      final request = invocation.positionalArguments.first as PriceRequest;
      final matte = request.options['paper'] == 'matte';
      return Ok<PriceQuote>(priceQuote(total: matte ? 180 : 130));
    });
    when(() => harness.api.createAnonymousSession(any())).thenAnswer(
      (_) async =>
          Ok<AuthSession>(AuthSession(token: 'guest-4', role: UserRole.guest)),
    );
    when(() => harness.api.createDesign(any()))
        .thenAnswer((_) async => Ok<DesignDto>(designFixture(id: 'dsg_opt')));

    await harness.pump(tester);
    harness.go(AppRoutes.productFor('photo_print'));
    await harness.settle(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await harness.settle(tester);

    expect(find.text('Опции'), findsOneWidget);
    expect(find.text('Тип бумаги'), findsOneWidget);

    await tester.tap(find.byKey(const Key('product-option-paper-matte')));
    await harness.settle(tester);

    expect(find.text('1,80 BYN'), findsOneWidget);
    expect(find.text('дороже на 0,50 BYN'), findsOneWidget);
    expect(find.textContaining('Глянцевая · −0,50 BYN'), findsOneWidget);

    await tester.tap(find.byKey(const Key('product-option-paper-gloss')));
    await harness.settle(tester);
    expect(find.textContaining('Матовая · +0,50 BYN'), findsOneWidget);
    expect(find.textContaining('дороже на'), findsNothing);

    await tester.tap(find.byKey(const Key('product-option-paper-matte')));
    await harness.settle(tester);

    await tester.tap(find.text('Собрать · 1,80 BYN'));
    await harness.settle(tester);

    final captured = verify(() => harness.api.price(captureAny())).captured;
    final request = captured.last as PriceRequest;
    expect(request.options, <String, String>{'paper': 'matte'});
    verifyNever(() => harness.api.createDesign(any()));
  });

  testWidgets('блок опций не показывается, когда их нет', (tester) async {
    final harness = FunnelHarness();
    when(() => harness.api.product('photo_print'))
        .thenAnswer((_) async => Ok<Product>(printProduct()));
    when(() => harness.api.price(any()))
        .thenAnswer((_) async => Ok<PriceQuote>(priceQuote(total: 130)));

    await harness.pump(tester);
    harness.go(AppRoutes.productFor('photo_print'));
    await harness.settle(tester);

    expect(find.text('Опции'), findsNothing);
  });
}
