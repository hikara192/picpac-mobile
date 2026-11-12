import 'package:api_contract/api_contract.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/app/bootstrap.dart';
import 'package:picpac_mobile/app/env.dart';
import 'package:picpac_mobile/core/clock.dart';
import 'package:picpac_mobile/core/orders/demo_controls.dart';
import 'package:picpac_mobile/core/storage/app_database.dart';
import 'package:picpac_mobile/network/token_store.dart';
import 'package:picpac_mobile/payments/payment_flow.dart';
import 'package:picpac_mobile/payments/payment_poller.dart';

import '../features/support/fixtures.dart';

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

  Future<void> signIn(
    AppDependencies dependencies, {
    String email = 'customer@picpac.test',
  }) async {
    await dependencies.tokens.clear();
    final result = await dependencies.api.login(
      LoginRequest(email: email, password: 'Test1234'),
    );
    expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
  }

  Future<Order> placeOrder(
    AppDependencies dependencies, {
    String? promoCode,
  }) async {
    final design = await dependencies.api.createDesign(documentedDesign());
    final added = await dependencies.api.addCartItem(
      AddCartItemRequest(designId: design.requireValue.id, quantity: 1),
    );
    var cart = added.requireValue;
    if (promoCode != null) {
      final discounted = await dependencies.api.updateCartItem(
        UpdateCartItemRequest(
          itemId: cart.items.first.id,
          promoCode: promoCode,
        ),
      );
      expect(discounted.isOk, isTrue, reason: '${discounted.failureOrNull}');
      cart = discounted.requireValue;
    }
    final points = (await dependencies.api.pickupPoints()).requireValue;
    final slot = points.first.slots.firstWhere(
      (candidate) => candidate.available,
    );
    final created = await dependencies.api.checkout(
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
        promoCode: cart.promoCode,
      ),
      idempotencyKey: 'order-${cart.id}',
    );
    expect(created.isOk, isTrue, reason: '${created.failureOrNull}');
    return created.requireValue;
  }

  test('карта: intent → sandbox-успех → поллинг → succeeded', () async {
    final dependencies = await boot();
    await signIn(dependencies);
    final order = await placeOrder(dependencies);

    final methods = await dependencies.api.paymentMethods(region: 'BY');
    expect(methods.isOk, isTrue, reason: '${methods.failureOrNull}');
    expect(
      methods.requireValue.map((method) => method.kind),
      containsAll(<String>['card', 'erip', 'cod']),
    );
    final card = methods.requireValue.firstWhere(
      (method) => method.kind == 'card',
    );
    expect(card.requiresRedirect, isTrue);

    final created = await dependencies.api.createPaymentIntent(
      CreatePaymentIntentRequest(
        orderId: order.id,
        methodId: card.id,
        region: 'BY',
      ),
      idempotencyKey: 'pay-${order.id}',
    );
    expect(created.isOk, isTrue, reason: '${created.failureOrNull}');
    final intent = created.requireValue;
    expect(intent.status, PaymentStatus.requiresAction);
    expect(intent.hostedPageUrl, isNotNull);
    expect(intent.amount.amountMinor, order.totals.total.amountMinor);

    final repeated = await dependencies.api.createPaymentIntent(
      CreatePaymentIntentRequest(
        orderId: order.id,
        methodId: card.id,
        region: 'BY',
      ),
      idempotencyKey: 'pay-${order.id}',
    );
    expect(repeated.requireValue.id, intent.id);

    final clock = _MutableClock(DateTime.now().toUtc());
    await signIn(dependencies, email: 'support@picpac.test');
    final controls = HttpDemoOrderControls(
      baseUrl: dependencies.baseUrl,
      tokens: dependencies.tokens,
    );
    final simulated = await controls.simulateCardSuccess(orderId: order.id);
    expect(simulated.isOk, isTrue, reason: '${simulated.failureOrNull}');

    await signIn(dependencies);
    final poller = PaymentPoller(
      fetch: (intentId) => dependencies.api.paymentIntent(intentId),
      delay: (duration) async => clock.advance(duration),
      clock: clock,
    );
    final outcome = await poller.start(intent.id);
    expect(outcome.stop, PaymentPollStop.status);
    expect(outcome.intent?.status, PaymentStatus.succeeded);

    final refreshed = await dependencies.api.order(order.id);
    expect(refreshed.isOk, isTrue, reason: '${refreshed.failureOrNull}');
    final paid = refreshed.requireValue;
    expect(paid.paymentStatus, PaymentStatus.succeeded);
    expect(paid.fulfillmentStatus, order.fulfillmentStatus);
    expect(paymentCallToAction(paid), PaymentCallToAction.receipt);

    final second = await dependencies.api.createPaymentIntent(
      CreatePaymentIntentRequest(
        orderId: order.id,
        methodId: card.id,
        region: 'BY',
      ),
      idempotencyKey: 'pay-again-${order.id}',
    );
    expect(second.isErr, isTrue);
    expect(second.failureOrNull?.code, 'payment_already_paid');
  });

  test('PIC100: заказ на 0 BYN оплачен сразу и не просит оплату', () async {
    final dependencies = await boot();
    await signIn(dependencies);
    final order = await placeOrder(dependencies, promoCode: 'PIC100');

    expect(order.totals.total.amountMinor, 0);
    expect(order.paymentStatus, PaymentStatus.succeeded);
    expect(paymentCallToAction(order), isNot(PaymentCallToAction.pay));

    final methods = await dependencies.api.paymentMethods(region: 'BY');
    final card = methods.requireValue.firstWhere(
      (method) => method.kind == 'card',
    );
    final refused = await dependencies.api.createPaymentIntent(
      CreatePaymentIntentRequest(
        orderId: order.id,
        methodId: card.id,
        region: 'BY',
      ),
      idempotencyKey: 'pay-zero-${order.id}',
    );
    expect(refused.isErr, isTrue);
    expect(refused.failureOrNull?.code, 'payment_already_paid');
  });
}

final class _MutableClock implements Clock {
  _MutableClock(this._instant);

  DateTime _instant;

  void advance(Duration duration) => _instant = _instant.add(duration);

  @override
  DateTime now() => _instant.toUtc();
}
