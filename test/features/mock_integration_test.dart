import 'dart:convert';
import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/app/bootstrap.dart';
import 'package:picpac_mobile/app/env.dart';
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

  Future<CheckoutRequest> preparedCheckout(AppDependencies dependencies) async {
    final design = await dependencies.api.createDesign(documentedDesign());
    final designId = design.requireValue.id;
    final added = await dependencies.api.addCartItem(
      AddCartItemRequest(designId: designId, quantity: 2),
    );
    final cart = added.requireValue;
    final points = (await dependencies.api.pickupPoints()).requireValue;
    PickupSlot? slot;
    for (final candidate in points.first.slots) {
      if (candidate.available) {
        slot = candidate;
        break;
      }
    }
    expect(slot, isNotNull, reason: 'the mock must offer a future pickup slot');
    return CheckoutRequest(
      cartId: cart.id,
      delivery: DeliverySelection(
        kind: DeliveryKind.pickup,
        optionId: 'pickup_main',
        pointId: points.first.id,
        slot: slot!.start,
      ),
      contact: const ContactInfo(
        name: 'Тестовый клиент',
        phone: '+375 29 123 45 67',
      ),
    );
  }

  test(
    'повтор checkout с тем же Idempotency-Key не создаёт второй заказ',
    () async {
      final dependencies = await boot();
      final login = await dependencies.api.login(
        const LoginRequest(email: 'customer@picpac.test', password: 'Test1234'),
      );
      expect(login.isOk, isTrue, reason: '${login.failureOrNull}');

      final request = await preparedCheckout(dependencies);
      const key = 'idempotency-test-key';

      final first = await dependencies.api.checkout(
        request,
        idempotencyKey: key,
      );
      final second = await dependencies.api.checkout(
        request,
        idempotencyKey: key,
      );

      expect(first.isOk, isTrue, reason: '${first.failureOrNull}');
      expect(second.isOk, isTrue, reason: '${second.failureOrNull}');
      expect(first.requireValue.id, second.requireValue.id);
      expect(first.requireValue.number, second.requireValue.number);

      final history = await dependencies.api.orders();
      expect(history.requireValue.orders, hasLength(1));
    },
  );

  test('тот же ключ с другим телом даёт idempotency_conflict', () async {
    final dependencies = await boot();
    await dependencies.api.login(
      const LoginRequest(email: 'customer@picpac.test', password: 'Test1234'),
    );
    final request = await preparedCheckout(dependencies);
    const key = 'idempotency-conflict-key';

    final first = await dependencies.api.checkout(request, idempotencyKey: key);
    expect(first.isOk, isTrue);

    final conflicting = await dependencies.api.checkout(
      CheckoutRequest(
        cartId: request.cartId,
        delivery: request.delivery,
        contact: const ContactInfo(name: 'Другой', phone: '+375 29 000 00 00'),
      ),
      idempotencyKey: key,
    );
    expect(conflicting.isErr, isTrue);
    expect(conflicting.failureOrNull?.code, ApiErrorCode.idempotencyConflict);
  });

  test('гостевой поиск: неверный номер и телефон дают один ответ', () async {
    final dependencies = await boot();
    await dependencies.api.login(
      const LoginRequest(email: 'customer@picpac.test', password: 'Test1234'),
    );
    final request = await preparedCheckout(dependencies);
    final created = await dependencies.api.checkout(
      request,
      idempotencyKey: 'lookup-key',
    );
    final order = created.requireValue;

    final wrongNumber = await dependencies.api.lookupOrder(
      number: 'PP-0000',
      phoneLast4: '4567',
    );
    final wrongPhone = await dependencies.api.lookupOrder(
      number: order.number,
      phoneLast4: '0000',
    );
    expect(wrongNumber.isErr, isTrue);
    expect(wrongPhone.isErr, isTrue);
    expect(wrongNumber.failureOrNull?.code, ApiErrorCode.notFound);
    expect(wrongPhone.failureOrNull?.code, ApiErrorCode.notFound);

    final found = await dependencies.api.lookupOrder(
      number: order.number,
      phoneLast4: '4567',
    );
    expect(found.isOk, isTrue, reason: '${found.failureOrNull}');
    expect(found.requireValue.id, order.id);
  });

  test('неизвестный статус заказа не ломает чтение', () async {
    final dependencies = await boot();
    await dependencies.api.login(
      const LoginRequest(email: 'customer@picpac.test', password: 'Test1234'),
    );
    final request = await preparedCheckout(dependencies);
    final created = await dependencies.api.checkout(
      request,
      idempotencyKey: 'unknown-status-key',
    );
    final order = created.requireValue;

    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final support = await dependencies.api.login(
      const LoginRequest(email: 'support@picpac.test', password: 'Test1234'),
    );
    expect(support.isOk, isTrue, reason: '${support.failureOrNull}');
    final token = dependencies.tokens.session!.token;
    final uri = Uri.parse(
      '${dependencies.baseUrl}/v1/mock/orders/${order.id}/advance',
    );
    final raw = await client.postUrl(uri);
    raw.headers
      ..contentType = ContentType.json
      ..set(HttpHeaders.authorizationHeader, 'Bearer $token');
    raw.write(jsonEncode(<String, Object?>{'to': 'quantum', 'force': true}));
    final response = await raw.close();
    expect(response.statusCode, 200);

    final after = await dependencies.api.order(order.id);
    expect(after.isOk, isTrue, reason: '${after.failureOrNull}');
    expect(after.requireValue.fulfillmentStatus, OrderStatus.unknown);
    expect(after.requireValue.hasUnknownStatus, isTrue);
    expect(after.requireValue.paymentStatus.isPaid, isFalse);
  });

  test('промокод применяется на сервере и виден в корзине', () async {
    final dependencies = await boot();
    await dependencies.api.login(
      const LoginRequest(email: 'customer@picpac.test', password: 'Test1234'),
    );
    final request = await preparedCheckout(dependencies);
    final before = (await dependencies.api.cart()).requireValue;

    final updated = await dependencies.api.updateCartItem(
      UpdateCartItemRequest(itemId: before.items.first.id, promoCode: 'TEST10'),
    );
    expect(updated.isOk, isTrue, reason: '${updated.failureOrNull}');
    final after = updated.requireValue;
    expect(after.promoCode, 'TEST10');
    expect(
      after.subtotal.amountMinor,
      lessThan(before.subtotal.amountMinor),
      reason: 'the discount is applied by the server',
    );
    expect(request.cartId, after.id);
  });
}
