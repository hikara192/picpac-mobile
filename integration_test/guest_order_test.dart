import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:picpac_mobile/app/di.dart';
import 'package:picpac_mobile/app/router.dart';
import 'package:picpac_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('гостевой поиск открывает заказ со статусной лентой', (
    tester,
  ) async {
    app.main();
    await _pumpUntil(tester, find.byType(Navigator));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
      listen: false,
    );
    final api = container.read(apiPortProvider);

    await container.read(tokenStoreProvider).clear();
    final login = await api.login(
      const LoginRequest(email: 'customer@picpac.test', password: 'Test1234'),
    );
    expect(login.isOk, isTrue, reason: '${login.failureOrNull}');

    final design = await api.createDesign(_photoPrintDesign());
    final designId = design.requireValue.id;
    await api.addCartItem(AddCartItemRequest(designId: designId, quantity: 2));
    final cart = (await api.cart()).requireValue;
    final points = (await api.pickupPoints()).requireValue;
    final slot = points.first.slots.firstWhere(
      (candidate) => candidate.available,
    );
    final created = await api.checkout(
      CheckoutRequest(
        cartId: cart.id,
        delivery: DeliverySelection(
          kind: DeliveryKind.pickup,
          optionId: 'pickup_main',
          pointId: points.first.id,
          slot: slot.start,
        ),
        contact: const ContactInfo(
          name: 'Тестовый клиент',
          phone: '+375 29 123 45 67',
        ),
      ),
      idempotencyKey: 'integration-guest-order',
    );
    expect(created.isOk, isTrue, reason: '${created.failureOrNull}');
    final order = created.requireValue;

    await container.read(tokenStoreProvider).clear();
    container.read(routerProvider).go(AppRoutes.orderLookup);
    await _pumpUntil(tester, find.text('Номер заказа'));

    await tester.enterText(find.byType(TextFormField).at(0), order.number);
    await tester.enterText(
      find.byType(TextFormField).at(1),
      order.contactPhoneLast4!,
    );
    await tester.tap(find.text('Найти'));
    await _pumpUntil(tester, find.text('Заказ ${order.number}'));

    expect(find.text('Код самовывоза'), findsNothing);
    expect(find.text('Готовность'), findsOneWidget);

    await _pumpUntil(tester, find.textContaining('Минск'));

    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}

DesignDocument _photoPrintDesign() => DesignDocument(
  revision: 1,
  product: const DocumentProduct(id: 'photo_print', formatId: '10x15'),
  spreads: <Spread>[
    Spread(
      id: 'spread_1',
      templateId: 'single_10x15',
      background: SpreadBackground.color('#FAF5ED'),
      slots: const <Slot>[Slot(id: 'main', photoId: 'photo_1')],
    ),
  ],
  spreadsCount: 1,
  assets: <PhotoAsset>[
    PhotoAsset(
      id: 'photo_1',
      sha256: 'a' * 64,
      widthPx: 1600,
      heightPx: 2400,
      mimeType: 'image/jpeg',
      bytes: 220000,
    ),
  ],
);

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('timed out waiting for $finder');
}
