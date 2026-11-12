import 'package:api_contract/api_contract.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:picpac_mobile/app/bootstrap.dart';
import 'package:picpac_mobile/app/env.dart';
import 'package:picpac_mobile/core/app_logger.dart';
import 'package:picpac_mobile/core/clock.dart';
import 'package:picpac_mobile/core/offline/offline_queue.dart';
import 'package:picpac_mobile/core/offline/pending_actions.dart';
import 'package:picpac_mobile/core/orders/order_cache.dart';
import 'package:picpac_mobile/core/storage/app_database.dart';
import 'package:picpac_mobile/network/token_store.dart';

import '../support/fixtures.dart';
import '../support/funnel_harness.dart';

void main() {
  setUpAll(registerFunnelFallbacks);

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

  Future<SupportTicket> createTicket(
    AppDependencies dependencies, {
    required String subject,
    String key = 'ticket-key',
  }) async {
    final result = await dependencies.api.createSupportTicket(
      CreateTicketRequest(
        subject: subject,
        body: 'Подробности обращения.',
        type: TicketType.defect,
      ),
      idempotencyKey: key,
    );
    expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
    return result.requireValue;
  }

  test('клиент видит только свои обращения, поддержка — все', () async {
    final dependencies = await boot();
    await signIn(dependencies);
    final own = await createTicket(dependencies, subject: 'Свой тикет');

    await dependencies.tokens.clear();
    await dependencies.api.createAnonymousSession(
      const AnonymousSessionRequest(locale: 'ru'),
    );
    final guestList = await dependencies.api.supportTickets();
    expect(guestList.isOk, isTrue, reason: '${guestList.failureOrNull}');
    expect(guestList.requireValue, isEmpty);
    final foreignRead = await dependencies.api.supportTicket(own.id);
    expect(foreignRead.isErr, isTrue);
    expect(foreignRead.failureOrNull?.code, ApiErrorCode.forbidden);

    await signIn(dependencies, email: 'support@picpac.test');
    final agentList = await dependencies.api.supportTickets();
    expect(agentList.isOk, isTrue, reason: '${agentList.failureOrNull}');
    expect(agentList.requireValue.map((ticket) => ticket.id), contains(own.id));
    final agentRead = await dependencies.api.supportTicket(own.id);
    expect(agentRead.isOk, isTrue, reason: '${agentRead.failureOrNull}');
  });

  test(
    'повтор создания тикета с тем же ключом возвращает тот же тикет',
    () async {
      final dependencies = await boot();
      await signIn(dependencies);
      final first = await createTicket(
        dependencies,
        subject: 'Повтор ключа',
        key: 'same-ticket-key',
      );
      final second = await createTicket(
        dependencies,
        subject: 'Повтор ключа',
        key: 'same-ticket-key',
      );
      expect(second.id, first.id);
      final list = await dependencies.api.supportTickets();
      expect(list.requireValue, hasLength(1));
    },
  );

  test('ответ в тикет идемпотентен по ключу', () async {
    final dependencies = await boot();
    await signIn(dependencies);
    final ticket = await createTicket(dependencies, subject: 'Ответ');
    const key = 'reply-key';
    final first = await dependencies.api.postTicketMessage(
      PostTicketMessageRequest(ticketId: ticket.id, body: 'Проверяем'),
      idempotencyKey: key,
    );
    final second = await dependencies.api.postTicketMessage(
      PostTicketMessageRequest(ticketId: ticket.id, body: 'Проверяем'),
      idempotencyKey: key,
    );
    expect(first.isOk, isTrue, reason: '${first.failureOrNull}');
    expect(second.requireValue.messages, hasLength(2));
    expect(
      second.requireValue.messages.map((message) => message.id),
      first.requireValue.messages.map((message) => message.id),
    );
  });

  test(
    'офлайн-checkout повторяется тем же ключом и не создаёт второй заказ',
    () async {
      final dependencies = await boot();
      await signIn(dependencies);
      final request = await _preparedCheckout(dependencies);
      const key = 'offline-checkout-key';

      final created = await dependencies.api.checkout(
        request,
        idempotencyKey: key,
      );
      expect(created.isOk, isTrue, reason: '${created.failureOrNull}');
      final order = created.requireValue;

      final store = PendingActionsStore(database: dependencies.database);
      final queue = OfflineQueue(
        api: dependencies.api,
        store: store,
        orders: OrderCache(database: dependencies.database),
        logger: const AppLogger(enabled: false),
        clock: const SystemClock(),
      );
      final queued = await queue.enqueueCheckout(request, idempotencyKey: key);
      expect(queued.idempotencyKey, key);

      final report = await queue.process();

      expect(report.sent, 1);
      expect(report.orderNumbers, <String>[order.number]);
      expect(await store.count(), 0, reason: 'доставленная запись удаляется');
      final history = await dependencies.api.orders();
      expect(
        history.requireValue.orders,
        hasLength(1),
        reason: 'повтор с тем же ключом не создаёт второй заказ',
      );
    },
  );

  test('попытки ограничены, после лимита нужен ручной повтор', () async {
    final api = FakeApi();
    when(
      () => api.checkout(any(), idempotencyKey: any(named: 'idempotencyKey')),
    ).thenAnswer((_) async => Err<Order>(ApiFailure.networkUnavailable()));

    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final clock = _MutableClock(testNow);
    final store = PendingActionsStore(database: database, clock: clock);
    final queue = OfflineQueue(
      api: api,
      store: store,
      orders: OrderCache(database: database),
      logger: const AppLogger(enabled: false),
      clock: clock,
    );
    await queue.enqueueCheckout(
      const CheckoutRequest(
        cartId: 'cart_1',
        delivery: DeliverySelection(kind: DeliveryKind.pickup),
        contact: ContactInfo(name: 'Клиент', phone: '+375 29 000 00 00'),
      ),
      idempotencyKey: 'bounded-key',
    );

    for (var i = 0; i < PendingActionsStore.maxAttempts; i++) {
      final report = await queue.process();
      expect(report.failed, 1);
      final skipped = await queue.process();
      expect(skipped.failed, 0);
      clock.advance(const Duration(minutes: 2));
    }

    final rows = await store.all();
    expect(rows.single.attempts, PendingActionsStore.maxAttempts);
    expect(rows.single.isExhausted, isTrue);

    final automatic = await queue.process();
    expect(automatic.failed, 0);
    verify(
      () => api.checkout(any(), idempotencyKey: any(named: 'idempotencyKey')),
    ).called(PendingActionsStore.maxAttempts);

    clearInteractions(api);
    when(
      () => api.checkout(any(), idempotencyKey: any(named: 'idempotencyKey')),
    ).thenAnswer((_) async => Ok<Order>(orderFixture()));
    final manual = await queue.retry(rows.single.id);
    expect(manual.sent, 1);
    final captured = verify(
      () => api.checkout(
        captureAny(),
        idempotencyKey: captureAny(named: 'idempotencyKey'),
      ),
    ).captured;
    expect(captured.last, 'bounded-key');
    expect(await store.count(), 0);
  });
}

Future<CheckoutRequest> _preparedCheckout(AppDependencies dependencies) async {
  final design = await dependencies.api.createDesign(documentedDesign());
  final added = await dependencies.api.addCartItem(
    AddCartItemRequest(designId: design.requireValue.id, quantity: 1),
  );
  final cart = added.requireValue;
  final points = (await dependencies.api.pickupPoints()).requireValue;
  final slot = points.first.slots.firstWhere(
    (candidate) => candidate.available,
  );
  return CheckoutRequest(
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
  );
}

final class _MutableClock implements Clock {
  _MutableClock(this._instant);

  DateTime _instant;

  void advance(Duration duration) => _instant = _instant.add(duration);

  @override
  DateTime now() => _instant.toUtc();
}
