import 'package:api_contract/api_contract.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/app/bootstrap.dart';
import 'package:picpac_mobile/app/env.dart';
import 'package:picpac_mobile/core/orders/demo_controls.dart';
import 'package:picpac_mobile/core/storage/app_database.dart';
import 'package:picpac_mobile/network/token_store.dart';

import 'support/fixtures.dart';

void main() {
  Future<AppDependencies> boot() async {
    final dependencies = await bootstrap(
      env: const AppEnv(apiMode: ApiMode.embedded, flavor: AppFlavor.dev),
      secureStore: InMemorySecureStore(),
      database: AppDatabase(NativeDatabase.memory()),
    );
    addTearDown(dependencies.dispose);
    return dependencies;
  }

  Future<Order> placeOrder(AppDependencies dependencies) async {
    await dependencies.api.login(
      const LoginRequest(email: 'customer@picpac.test', password: 'Test1234'),
    );
    final design = await dependencies.api.createDesign(documentedDesign());
    final designId = design.requireValue.id;
    final added = await dependencies.api.addCartItem(
      AddCartItemRequest(designId: designId, quantity: 1),
    );
    final points = (await dependencies.api.pickupPoints()).requireValue;
    final slot = points.first.slots.firstWhere((slot) => slot.available);
    final created = await dependencies.api.checkout(
      CheckoutRequest(
        cartId: added.requireValue.id,
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
      idempotencyKey: 'demo-status-key',
    );
    return created.requireValue;
  }

  test('клиент двигает ленту отменой и оплачивает hosted-страницу', () async {
    final dependencies = await boot();
    final order = await placeOrder(dependencies);
    expect(order.fulfillmentStatus, OrderStatus.placed);

    final controls = HttpDemoOrderControls(
      baseUrl: dependencies.baseUrl,
      tokens: dependencies.tokens,
    );

    final next = await controls.advance(order.id);
    expect(next.isErr, isTrue, reason: '${next.failureOrNull}');
    expect(isAdvanceNeedsSupport(next.failureOrNull!), isTrue);
    expect(
      isDemoEndpointUnavailable(next.failureOrNull!),
      isFalse,
      reason: 'the endpoint exists — the role is limited',
    );

    final intent = await dependencies.api.createPaymentIntent(
      CreatePaymentIntentRequest(orderId: order.id, methodId: 'bank_card'),
      idempotencyKey: 'demo-intent-${order.id}',
    );
    expect(intent.isOk, isTrue, reason: '${intent.failureOrNull}');
    final created = intent.requireValue;
    expect(created.status, isNot(PaymentStatus.succeeded));
    final hosted = created.hostedPageUrl;
    expect(hosted, isNotNull);

    final confirmed = await controls.confirmHostedPayment(Uri.parse(hosted!));
    expect(confirmed.isOk, isTrue, reason: '${confirmed.failureOrNull}');

    final verified = await dependencies.api.paymentIntent(created.id);
    expect(verified.requireValue.status, PaymentStatus.succeeded);

    final paid = (await dependencies.api.order(order.id)).requireValue;
    expect(paid.paymentStatus, PaymentStatus.succeeded);
    expect(paid.fulfillmentStatus, OrderStatus.placed);
    expect(paid.history, hasLength(1));

    final canceled = await controls.advance(order.id, to: 'canceled');
    expect(canceled.isOk, isTrue, reason: '${canceled.failureOrNull}');
    expect(canceled.requireValue.fulfillmentStatus, OrderStatus.canceled);
    expect(canceled.requireValue.paymentStatus, PaymentStatus.succeeded);
    expect(canceled.requireValue.history, hasLength(2));

    final simulated = await controls.simulateCardSuccess(orderId: order.id);
    expect(simulated.isErr, isTrue);
    expect(isDemoEndpointUnavailable(simulated.failureOrNull!), isTrue);
  });

  test('неизвестный заказ — типизированная ошибка, а не падение', () async {
    final dependencies = await boot();
    await placeOrder(dependencies);
    final controls = HttpDemoOrderControls(
      baseUrl: dependencies.baseUrl,
      tokens: dependencies.tokens,
    );

    final missing = await controls.advance('ord_missing');
    expect(missing.isErr, isTrue);
    expect(isDemoEndpointUnavailable(missing.failureOrNull!), isTrue);
  });
}
