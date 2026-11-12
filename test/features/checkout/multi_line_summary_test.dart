import 'package:api_contract/api_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:picpac_mobile/features/checkout/application/checkout_controller.dart';

import '../support/fixtures.dart';
import '../support/funnel_harness.dart';

void main() {
  setUpAll(registerFunnelFallbacks);

  Cart twoLineCart() => Cart(
    id: 'cart_1',
    items: <CartItem>[
      CartItem(
        id: 'cli_1',
        designId: 'dsg_1',
        quantity: 1,
        quote: priceQuote(total: 1000, production: 1000, etaDays: 2),
      ),
      CartItem(
        id: 'cli_2',
        designId: 'dsg_2',
        quantity: 1,
        quote: priceQuote(total: 1000, production: 1000, etaDays: 3),
      ),
    ],
    expiresAt: DateTime.utc(2026, 11, 25),
    subtotal: byn(2000),
  );

  testWidgets('итог равен сумме серверных quote.total, доставка — один раз', (
    tester,
  ) async {
    final harness = FunnelHarness();
    when(() => harness.api.cart())
        .thenAnswer((_) async => Ok<Cart>(twoLineCart()));
    when(() => harness.api.catalog())
        .thenAnswer((_) async => Ok<CatalogResponse>(catalogResponse()));
    when(() => harness.api.design('dsg_1'))
        .thenAnswer((_) async => Ok<DesignDto>(designFixture()));
    when(() => harness.api.design('dsg_2'))
        .thenAnswer((_) async => Ok<DesignDto>(designFixture(id: 'dsg_2')));
    when(() => harness.api.deliveryOptions()).thenAnswer(
      (_) async => Ok<List<DeliveryOption>>(<DeliveryOption>[
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
    when(() => harness.api.pickupPoints())
        .thenAnswer((_) async => Ok<List<PickupPoint>>(<PickupPoint>[]));
    when(() => harness.api.price(any())).thenAnswer((invocation) async {
      final request = invocation.positionalArguments.first as PriceRequest;
      return Ok<PriceQuote>(
        request.delivery == null
            ? priceQuote(total: 1000, production: 1000, etaDays: 2)
            : priceQuote(
                total: 1590,
                delivery: 590,
                production: 1000,
                etaDays: 4,
              ),
      );
    });

    await harness.pump(tester);

    const choice = DeliveryChoice(
      optionId: 'europochta',
      kind: DeliveryKind.post,
      address: 'Минск, Минский проспект 32',
    );
    final summary = await harness.container.read(
      checkoutSummaryProvider(choice).future,
    );

    expect(summary.total, byn(2590));
    expect(summary.etaDays, 4);
    expect(
      summary.lines.fold<int>(0, (sum, line) => sum + line.amount.amountMinor),
      2590,
    );
    expect(summary.exact, isFalse);

    final requests = verify(() => harness.api.price(captureAny())).captured
        .cast<PriceRequest>();
    expect(requests, hasLength(2));
    expect(requests.where((request) => request.delivery != null), hasLength(1));
  });
}
