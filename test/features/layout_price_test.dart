import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:picpac_mobile/app/router.dart';

import 'support/design_fixtures.dart';
import 'support/design_harness.dart';

void main() {
  setUpAll(() {
    registerDesignFallbacks();
    registerFallbackValue(const UpdateCartItemRequest(itemId: 'i'));
  });

  Cart printCart({required int quantity, required int totalMinor}) => Cart(
    id: 'cart_1',
    items: <CartItem>[
      CartItem(
        id: 'cli_1',
        designId: 'dsg_1',
        quantity: quantity,
        quote: PriceQuote(
          total: Money(amountMinor: totalMinor, currency: 'BYN'),
          breakdown: <PriceBreakdownLine>[
            PriceBreakdownLine(
              code: 'product',
              labelKey: 'price.product',
              amount: Money(amountMinor: totalMinor, currency: 'BYN'),
            ),
          ],
          etaDays: 2,
          canOrder: true,
          deliveryMinor: 0,
          productionMinor: totalMinor,
        ),
      ),
    ],
    expiresAt: DateTime.utc(2026, 11, 25),
    subtotal: Money(amountMinor: totalMinor, currency: 'BYN'),
  );

  testWidgets('«Так лучше»: корзина пересчитывается только ответом сервера', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 10);
    expect(document.spreads, hasLength(10), reason: 'one photo per sheet');
    harness.stubBasics(design: designDto(document: document));

    var serverDocument = document;
    when(() => harness.api.design(any())).thenAnswer(
      (_) async => Ok<DesignDto>(designDto(document: serverDocument)),
    );
    when(() => harness.api.cart()).thenAnswer(
      (_) async => Ok<Cart>(printCart(quantity: 10, totalMinor: 1300)),
    );
    const serverTotal = 550;
    when(
      () => harness.api.updateCartItem(any(that: isA<UpdateCartItemRequest>())),
    ).thenAnswer(
      (_) async => Ok<Cart>(printCart(quantity: 4, totalMinor: serverTotal)),
    );

    await harness.pump(tester, location: AppRoutes.createFor('dsg_1'));

    expect(find.text('Можно плотнее'), findsOneWidget);
    expect(find.textContaining('4 листа'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Так лучше'));
    await harness.settle(tester);
    expect(harness.session!.document.spreads, hasLength(4));
    await harness.settleReal(tester, frames: 4);
    serverDocument = harness.session!.document;

    harness.container.read(routerProvider).go(AppRoutes.cart);
    await harness.settleReal(tester, frames: 20);

    expect(find.text('4 листа'), findsOneWidget);
    expect(find.text('Корзина пересчитана по текущему макету'), findsOneWidget);
    const expected = '5,50 BYN';
    expect(find.text(expected), findsNWidgets(2));
    expect(
      find.text('5,20 BYN'),
      findsNothing,
      reason: 'the client must not multiply sheets by a price',
    );

    final captured = verify(() => harness.api.updateCartItem(captureAny()))
        .captured;
    expect(captured, hasLength(1));
    final request = captured.single as UpdateCartItemRequest;
    expect(request.itemId, 'cli_1');
    expect(request.quantity, 4, reason: 'the reconcile uses the new layout');

    await harness.disposeForTest(tester);
  });
}
