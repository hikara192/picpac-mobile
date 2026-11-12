import 'package:api_contract/api_contract.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/app/bootstrap.dart';
import 'package:picpac_mobile/app/env.dart';
import 'package:picpac_mobile/core/storage/app_database.dart';
import 'package:picpac_mobile/network/token_store.dart';

Future<AppDependencies> _boot() => bootstrap(
  env: const AppEnv(apiMode: ApiMode.embedded, flavor: AppFlavor.dev),
  secureStore: InMemorySecureStore(),
  database: AppDatabase(NativeDatabase.memory()),
);

void main() {
  test('embedded mock serves the catalogue over HTTP', () async {
    final dependencies = await _boot();
    addTearDown(dependencies.dispose);

    expect(dependencies.embeddedServer, isNotNull);
    final catalog = await dependencies.api.catalog();
    expect(catalog.isOk, isTrue, reason: '${catalog.failureOrNull}');
    final products = catalog.requireValue.products;
    expect(products, isNotEmpty);
    expect(products.first.formats, isNotEmpty);
  });

  test('guest can price a photo print through the embedded API', () async {
    final dependencies = await _boot();
    addTearDown(dependencies.dispose);

    final session = await dependencies.api.createAnonymousSession(
      const AnonymousSessionRequest(locale: 'ru'),
    );
    expect(session.isOk, isTrue, reason: '${session.failureOrNull}');

    final deliveryOptions = await dependencies.api.deliveryOptions();
    expect(
      deliveryOptions.isOk,
      isTrue,
      reason: '${deliveryOptions.failureOrNull}',
    );
    final pickup = deliveryOptions.requireValue.firstWhere(
      (option) => option.kind == DeliveryKind.pickup,
    );
    final points = await dependencies.api.pickupPoints();
    final point = points.requireValue.first;

    final quote = await dependencies.api.price(
      PriceRequest(
        productId: 'photo_print',
        formatId: '10x15',
        photosCount: 10,
        spreadsCount: 10,
        delivery: DeliverySelection(
          kind: DeliveryKind.pickup,
          optionId: pickup.id,
          pointId: point.id,
        ),
      ),
    );
    expect(quote.isOk, isTrue, reason: '${quote.failureOrNull}');
    final value = quote.requireValue;
    expect(value.total.amountMinor, greaterThan(0));
    expect(value.etaDays, greaterThan(0));
    expect(value.canOrder, isTrue);
  });

  test('price reacts to a promo code and stays in minor units', () async {
    final dependencies = await _boot();
    addTearDown(dependencies.dispose);
    await dependencies.api.createAnonymousSession(
      const AnonymousSessionRequest(locale: 'ru'),
    );

    final options = await dependencies.api.deliveryOptions();
    final pickup = options.requireValue.firstWhere(
      (option) => option.kind == DeliveryKind.pickup,
    );
    final points = await dependencies.api.pickupPoints();
    final delivery = DeliverySelection(
      kind: DeliveryKind.pickup,
      optionId: pickup.id,
      pointId: points.requireValue.first.id,
    );

    PriceRequest request({String? promo}) => PriceRequest(
      productId: 'photo_print',
      formatId: '10x15',
      photosCount: 10,
      spreadsCount: 10,
      delivery: delivery,
      promoCode: promo,
    );

    final base = await dependencies.api.price(request());
    final discounted = await dependencies.api.price(request(promo: 'TEST10'));
    expect(base.isOk && discounted.isOk, isTrue);
    expect(
      discounted.requireValue.total.amountMinor,
      lessThan(base.requireValue.total.amountMinor),
    );
    expect(discounted.requireValue.total.currency, 'BYN');
  });
}
