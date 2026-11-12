import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  late MockApi api;
  late String token;

  setUp(() async {
    api = MockApi();
    token = await api.login();
  });

  group('cart', () {
    test('adds, re-prices, updates and removes a line', () async {
      final design = await api.createPrintDesign(token);
      final id = design['id']! as String;

      final added = await api.addToCart(token, id, quantity: 10);
      final cart = Cart.fromJson(added);
      expect(cart.items, hasLength(1));
      expect(cart.items.single.quote.total.amountMinor, 1300);
      expect(cart.subtotal.amountMinor, 1300);
      expect(cart.expiresAt.difference(api.clock.now()).inDays, 14);
      expect(cart.canCheckout, isTrue);

      final patched = await api.call(
        'PATCH',
        '/v1/cart/items/${cart.items.single.id}',
        token: token,
        body: <String, Object?>{'quantity': 20},
      );
      expect(patched.status, 200, reason: patched.text);
      expect(Cart.fromJson(patched.object).subtotal.amountMinor, 2600);

      final removed = await api.call(
        'DELETE',
        '/v1/cart/items/${cart.items.single.id}',
        token: token,
      );
      expect(removed.status, 200);
      final empty = Cart.fromJson(removed.object);
      expect(empty.isEmpty, isTrue);
      expect(empty.canCheckout, isFalse);
    });

    test('rejects an unknown promo on the cart', () async {
      final design = await api.createPrintDesign(token);
      final cart = await api.addToCart(token, design['id']! as String);
      final itemId = (cart['items']! as List).single as Map<String, Object?>;
      final response = await api.call(
        'PATCH',
        '/v1/cart/items/${itemId['id']}',
        token: token,
        body: <String, Object?>{'promoCode': 'NOPE'},
      );
      expectError(response, 422, 'promo_unknown');
    });

    test('applies a cart-level promo to every line', () async {
      final design = await api.createPrintDesign(token);
      final cart = await api.addToCart(
        token,
        design['id']! as String,
        quantity: 10,
      );
      final itemId = (cart['items']! as List).single as Map<String, Object?>;
      final response = await api.call(
        'PATCH',
        '/v1/cart/items/${itemId['id']}',
        token: token,
        body: <String, Object?>{'promoCode': 'TEST10'},
      );
      final priced = Cart.fromJson(response.object);
      expect(priced.promoCode, 'TEST10');
      expect(priced.subtotal.amountMinor, 1170);
      expect(priced.items.single.quote.total.amountMinor, 1170);
    });

    test('expires after 14 days with an audit record', () async {
      final design = await api.createPrintDesign(token);
      final first = Cart.fromJson(
        await api.addToCart(token, design['id']! as String),
      );

      api.clock.advance(const Duration(days: 14, minutes: 1));
      token = await api.login();
      final refreshed = await api.call('GET', '/v1/cart', token: token);
      final second = Cart.fromJson(refreshed.object);
      expect(second.id, isNot(first.id));
      expect(second.items, isEmpty);
      expect(second.expiresAt.isAfter(api.clock.now()), isTrue);

      final support = await api.loginSupport();
      final audit = await api.call(
        'GET',
        '/v1/audit?objectType=cart&limit=100',
        token: support,
      );
      expect(audit.status, 200, reason: audit.text);
      expect(
        audit.list.cast<Map<String, Object?>>().map((entry) => entry['action']),
        contains('cart.expire'),
      );
    });

    test('isolates carts between customers', () async {
      final other = api.registerCustomer('cus_other');
      final design = await api.createPrintDesign(token);
      await api.addToCart(token, design['id']! as String);

      final foreign = await api.call('GET', '/v1/cart', token: other);
      expect(Cart.fromJson(foreign.object).items, isEmpty);
    });
  });

  group('checkout', () {
    test(
      'converts a cart into an order with a number and two status axes',
      () async {
        final order = await api.placeOrder(token);
        final parsed = Order.fromJson(order);
        expect(parsed.number, matches(RegExp(r'^PP-\d{4}$')));
        expect(parsed.items, hasLength(1));
        expect(parsed.items.single.quantity, 10);
        expect(parsed.items.single.unitPrice.amountMinor, 130);
        expect(parsed.items.single.total.amountMinor, 1300);
        expect(parsed.totals.subtotal.amountMinor, 1300);
        expect(parsed.totals.delivery.amountMinor, 0);
        expect(parsed.totals.total.amountMinor, 1300);
        expect(parsed.paymentStatus, PaymentStatus.created);
        expect(parsed.fulfillmentStatus, OrderStatus.placed);
        expect(parsed.history.single.status, OrderStatus.placed);
        expect(parsed.delivery.isPickup, isTrue);
        expect(parsed.delivery.pickupCode, matches(RegExp(r'^\d{4}$')));
        expect(parsed.eta, isNotNull);
        expect(parsed.contactPhoneLast4, '4567');

        final reused = await api.call(
          'POST',
          '/v1/checkout',
          token: token,
          headers: <String, String>{'idempotency-key': 'another-key'},
          body: <String, Object?>{
            'cartId': parsed.id,
            'delivery': await api.pickupSelection(),
            'contact': <String, Object?>{'name': 'X', 'phone': '+375291234567'},
          },
        );
        expectError(reused, 409, 'cart_expired');
      },
    );

    test('replays the same order for the same key and body', () async {
      final design = await api.createPrintDesign(token);
      final cart = await api.addToCart(
        token,
        design['id']! as String,
        quantity: 3,
      );
      final cartId = cart['id']! as String;

      final first = await api.checkout(
        token,
        cartId: cartId,
        idempotencyKey: 'key-42',
      );
      expect(first.status, 201, reason: first.text);
      final second = await api.checkout(
        token,
        cartId: cartId,
        idempotencyKey: 'key-42',
      );
      expect(second.status, 200, reason: second.text);
      expect(second.header('idempotent-replay'), 'true');
      expect(second.object['id'], first.object['id']);
      expect(second.object['number'], first.object['number']);
      expect(api.server.orders, hasLength(1));
    });

    test('rejects the same key with a different body', () async {
      final design = await api.createPrintDesign(token);
      final cart = await api.addToCart(token, design['id']! as String);
      final cartId = cart['id']! as String;
      final delivery = await api.pickupSelection();

      final first = await api.call(
        'POST',
        '/v1/checkout',
        token: token,
        headers: <String, String>{'idempotency-key': 'key-7'},
        body: <String, Object?>{
          'cartId': cartId,
          'delivery': delivery,
          'contact': <String, Object?>{'name': 'A', 'phone': '+375291234567'},
        },
      );
      expect(first.status, 201, reason: first.text);

      final conflicting = await api.call(
        'POST',
        '/v1/checkout',
        token: token,
        headers: <String, String>{'idempotency-key': 'key-7'},
        body: <String, Object?>{
          'cartId': cartId,
          'delivery': delivery,
          'contact': <String, Object?>{'name': 'B', 'phone': '+375291234567'},
        },
      );
      expectError(conflicting, 422, ApiErrorCode.idempotencyConflict);
      expect(api.server.orders, hasLength(1));
    });

    test('requires the Idempotency-Key header', () async {
      final response = await api.call(
        'POST',
        '/v1/checkout',
        token: token,
        body: <String, Object?>{},
      );
      expectError(response, 400, 'idempotency_key_required');
    });

    test('creates a direct order without a cart', () async {
      final design = await api.createPrintDesign(token);
      final response = await api.directOrder(
        token,
        design['id']! as String,
        quantity: 2,
      );
      expect(response.status, 201, reason: response.text);
      final order = Order.fromJson(response.object);
      expect(order.items.single.quantity, 2);
      expect(order.totals.total.amountMinor, 260);
    });

    test('blocks checkout when preflight has blocking issues', () async {
      final design = await api.call(
        'POST',
        '/v1/designs',
        token: token,
        body: emptySlotDesignJson(),
      );
      final id = design.object['id']! as String;
      final cart = await api.addToCart(token, id);
      final response = await api.checkout(token, cartId: cart['id']! as String);
      expectError(response, 422, 'preflight_blocked');
      expect(fieldErrors(response)['lines.$id'], 'preflight_blocked');
    });

    test('a 100 % promo order is paid at creation with no intent', () async {
      final order = await api.placeOrder(
        token,
        idempotencyKey: 'free-key',
        promoCode: 'PIC100',
      );
      final parsed = Order.fromJson(order);
      expect(parsed.totals.total.amountMinor, 0);
      expect(parsed.paymentStatus, PaymentStatus.succeeded);
      expect(parsed.fulfillmentStatus, OrderStatus.placed);
      expect(api.server.intents, isEmpty);
      expect(parsed.totals.discount.amountMinor, -1300);
    });
  });
}
