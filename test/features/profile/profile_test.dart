import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:picpac_mobile/app/di.dart';
import 'package:picpac_mobile/app/env.dart';
import 'package:picpac_mobile/app/router.dart';
import 'package:picpac_mobile/core/clock.dart';
import 'package:picpac_mobile/core/offline/offline_queue.dart';
import 'package:picpac_mobile/core/offline/pending_actions.dart';
import 'package:picpac_mobile/core/orders/order_cache.dart';
import 'package:picpac_mobile/core/storage/app_database.dart';
import 'package:picpac_mobile/core/storage/draft_store.dart';
import 'package:picpac_mobile/features/_shared/application/design_format.dart';
import 'package:picpac_mobile/features/profile/application/profile_controller.dart';
import 'package:picpac_mobile/network/token_store.dart';

import '../support/fixtures.dart';
import '../support/funnel_harness.dart';

void main() {
  setUpAll(registerFunnelFallbacks);

  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  Customer customerFixture() => Customer(
    id: 'cus_demo',
    createdAt: testNow,
    name: 'Тестовый клиент',
    email: 'customer@picpac.test',
    phoneMasked: '+375 ** *** 12 34',
  );

  testWidgets('профиль показывает данные сессии без служебных плиток', (
    tester,
  ) async {
    useTallViewport(tester);
    final harness = FunnelHarness();
    when(() => harness.api.currentCustomer())
        .thenAnswer((_) async => Ok<Customer>(customerFixture()));

    await harness.pump(tester);
    harness.go(AppRoutes.profile);
    await harness.settle(tester);

    expect(find.text('Тестовый клиент'), findsWidgets);
    expect(find.text('customer@picpac.test'), findsWidgets);
    expect(find.text('Клиент'), findsNothing);
    expect(find.text('С нами с'), findsOneWidget);
    expect(find.text('+375 ** *** 12 34'), findsOneWidget);
    expect(find.text('Все действия отправлены.'), findsOneWidget);
    expect(find.text('Удалить аккаунт'), findsOneWidget);
  });

  testWidgets('удаление аккаунта требует двух подтверждений с явным текстом', (
    tester,
  ) async {
    useTallViewport(tester);
    final harness = FunnelHarness();
    when(() => harness.api.currentCustomer())
        .thenAnswer((_) async => Ok<Customer>(customerFixture()));

    await harness.pump(tester);
    harness.go(AppRoutes.profile);
    await harness.settle(tester);

    await tester.scrollUntilVisible(
      find.text('Удалить аккаунт'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Удалить аккаунт'));
    await harness.settle(tester);

    expect(find.text('Удалить аккаунт и все данные?'), findsOneWidget);
    expect(
      find.textContaining('заказы, обращения в поддержку, черновики'),
      findsOneWidget,
    );

    await tester.tap(find.text('Продолжить'));
    await harness.settle(tester);

    expect(find.text('Последнее подтверждение'), findsOneWidget);
    expect(
      find.textContaining('и все связанные данные будут удалены безвозвратно'),
      findsOneWidget,
    );
    expect(find.text('Удалить безвозвратно'), findsOneWidget);

    await tester.tap(find.text('Отмена'));
    await harness.settle(tester);

    verifyNever(() => harness.api.deleteAccount());
    expect(find.text('Удалить безвозвратно'), findsNothing);
  });

  testWidgets('очередь видна в профиле и повторяется вручную', (tester) async {
    useTallViewport(tester);
    final harness = FunnelHarness();
    when(() => harness.api.currentCustomer())
        .thenAnswer((_) async => Ok<Customer>(customerFixture()));
    when(
      () => harness.api.postTicketMessage(
        any(),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer(
      (_) async =>
          Ok<SupportTicket>(supportTicketFixture(status: TicketStatus.pending)),
    );

    await harness.pump(tester);
    final store = PendingActionsStore(
      database: harness.database,
      clock: harness.clock,
    );
    final queued = await store.add(
      kind: PendingActionKind.postMessage,
      payload: const PostTicketMessageRequest(
        ticketId: 'tkt_1',
        body: 'Не ушло без сети',
      ).toJson(),
      idempotencyKey: 'queue-key-1',
    );
    for (var i = 0; i < PendingActionsStore.maxAttempts; i++) {
      await store.recordAttempt(queued.id);
    }
    harness.container.invalidate(pendingActionsControllerProvider);

    harness.go(AppRoutes.profile);
    await harness.settle(tester);

    expect(find.text('Сообщение в поддержку'), findsOneWidget);
    expect(find.text('Не отправлено'), findsOneWidget);
    expect(
      find.textContaining('${PendingActionsStore.maxAttempts} попыток'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Повторить'));
    await harness.settle(tester);

    verify(
      () => harness.api.postTicketMessage(any(), idempotencyKey: 'queue-key-1'),
    ).called(1);
    expect(await store.count(), 0);
    expect(find.text('Отправлено: 1'), findsOneWidget);
  });

  testWidgets('401 на профиле разлогинивает и ведёт на вход', (tester) async {
    useTallViewport(tester);
    final harness = FunnelHarness();
    when(() => harness.api.currentCustomer()).thenAnswer(
      (_) async => Err<Customer>(
        const ApiFailure(
          code: ApiErrorCode.unauthorized,
          message: 'the session has expired',
          statusCode: 401,
        ),
      ),
    );

    await harness.pump(tester);
    harness.go(AppRoutes.profile);
    await harness.settle(tester);

    expect(harness.tokens.session, isNull);
    expect(find.text('Вход в PicPac'), findsOneWidget);
  });

  group('каскад удаления на уровне данных', () {
    late Directory root;
    late AppDatabase database;
    late TokenStore tokens;
    late FakeApi api;
    late ProviderContainer container;
    late DraftStore drafts;

    setUp(() {
      registerFunnelFallbacks();
      root = Directory.systemTemp.createTempSync('picpac_profile_');
      database = AppDatabase(NativeDatabase.memory());
      tokens = TokenStore(InMemorySecureStore());
      api = FakeApi();
      drafts = DraftStore(database: database, rootDirectory: () async => root);
      container = ProviderContainer(
        overrides: <Override>[
          ...appOverrides(
            env: const AppEnv(apiMode: ApiMode.embedded, flavor: AppFlavor.dev),
            api: api,
            tokens: tokens,
            database: database,
            clock: FixedClock(testNow),
          ),
          draftStoreProvider.overrideWithValue(drafts),
          draftRootProvider.overrideWithValue(() async => root),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await database.close();
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    Future<void> seedLocalData() async {
      await drafts.saveNow(
        documentedDesign(),
        designId: 'dsg_1',
        productId: 'photo_print',
      );
      await container
          .read(pendingActionsStoreProvider)
          .add(
            kind: PendingActionKind.createTicket,
            payload: const CreateTicketRequest(
              subject: 'Тема',
              body: 'Текст',
              type: TicketType.question,
            ).toJson(),
            idempotencyKey: 'ticket-key',
          );
      await container.read(orderCacheProvider).save(orderFixture());
    }

    test('удаление аккаунта чистит черновики, очередь, кеш и токен', () async {
      await tokens.save(
        const AuthSession(token: 'customer-token', role: UserRole.customer),
      );
      when(() => api.createAnonymousSession(any())).thenAnswer(
        (_) async => Ok<AuthSession>(
          const AuthSession(token: 'guest-token', role: UserRole.guest),
        ),
      );
      when(() => api.deleteAccount())
          .thenAnswer((_) async => const Ok<void>(null));
      await seedLocalData();

      expect(await drafts.list(), hasLength(1));

      final result = await container
          .read(accountActionsProvider.notifier)
          .deleteAccount();

      expect(result.isOk, isTrue);
      expect(await drafts.list(), isEmpty);
      expect(await container.read(pendingActionsStoreProvider).count(), 0);
      expect(await container.read(orderCacheProvider).recent(), isEmpty);
      expect(tokens.session?.role, UserRole.guest);
      expect(tokens.session?.token, isNot('customer-token'));
    });

    test('удаление тестовых данных не трогает аккаунт на сервере', () async {
      await tokens.save(
        const AuthSession(token: 'customer-token', role: UserRole.customer),
      );
      when(() => api.deleteAccount())
          .thenAnswer((_) async => const Ok<void>(null));
      await seedLocalData();

      final removed = await container
          .read(accountActionsProvider.notifier)
          .deleteTestData();

      expect(removed, 1);
      expect(await drafts.list(), isEmpty);
      expect(await container.read(pendingActionsStoreProvider).count(), 0);
      expect(tokens.session?.token, 'customer-token');
      verifyNever(() => api.deleteAccount());
    });
  });
}
