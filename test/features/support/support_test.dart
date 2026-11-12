import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:picpac_mobile/app/router.dart';
import 'package:picpac_mobile/core/offline/pending_actions.dart';

import '../support/fixtures.dart';
import '../support/funnel_harness.dart';

void main() {
  setUpAll(registerFunnelFallbacks);

  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  Future<void> sendReply(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('support-reply')), text);
    await tester.pump();
    await tester.tap(find.byTooltip('Отправить'));
  }

  testWidgets('клиент видит свои обращения, статус — текстом', (tester) async {
    useTallViewport(tester);
    final harness = FunnelHarness();
    when(() => harness.api.supportTickets()).thenAnswer(
      (_) async => Ok<List<SupportTicket>>(<SupportTicket>[
        supportTicketFixture(subject: 'Фото с полосой'),
        supportTicketFixture(
          id: 'tkt_2',
          subject: 'Не пришёл заказ',
          status: TicketStatus.resolved,
          type: TicketType.delivery,
        ),
      ]),
    );

    await harness.pump(tester);
    harness.go(AppRoutes.support);
    await harness.settle(tester);

    expect(find.text('Фото с полосой'), findsOneWidget);
    expect(find.text('Не пришёл заказ'), findsOneWidget);
    expect(find.text('Открыто'), findsOneWidget);
    expect(find.text('Решено'), findsOneWidget);
    expect(find.text('Режим поддержки'), findsNothing);
  });

  testWidgets('пустой список объясняет, что делать дальше', (tester) async {
    useTallViewport(tester);
    final harness = FunnelHarness();
    when(() => harness.api.supportTickets())
        .thenAnswer((_) async => Ok<List<SupportTicket>>(<SupportTicket>[]));

    await harness.pump(tester);
    harness.go(AppRoutes.support);
    await harness.settle(tester);

    expect(find.text('Обращений пока нет'), findsOneWidget);
    expect(find.text('Новое обращение'), findsOneWidget);
  });

  testWidgets('тред различает автора и время, ответ уходит с ключом', (
    tester,
  ) async {
    useTallViewport(tester);
    final harness = FunnelHarness();
    final ticket = supportTicketFixture(
      messages: <TicketMessage>[
        ticketMessageFixture(body: 'Фото пришли с полосой.'),
        ticketMessageFixture(
          id: 'msg_2',
          author: UserRole.supportAgent,
          body: 'Проверим и перепечатаем.',
        ),
      ],
    );
    when(() => harness.api.supportTicket('tkt_1'))
        .thenAnswer((_) async => Ok<SupportTicket>(ticket));
    when(
      () => harness.api.postTicketMessage(
        any(),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer(
      (_) async => Ok<SupportTicket>(
        supportTicketFixture(
          status: TicketStatus.pending,
          messages: <TicketMessage>[
            ...ticket.messages,
            ticketMessageFixture(
              id: 'msg_3',
              body: 'Спасибо, жду перепечатку!',
            ),
          ],
        ),
      ),
    );

    await harness.pump(tester);
    harness.go('${AppRoutes.support}/tkt_1');
    await harness.settle(tester);

    expect(find.text('Фото пришли с полосой.'), findsOneWidget);
    expect(find.text('Проверим и перепечатаем.'), findsOneWidget);
    expect(find.text('Вы'), findsOneWidget);
    expect(find.text('Поддержка'), findsWidgets);

    await sendReply(tester, 'Спасибо, жду перепечатку!');
    await harness.settle(tester);

    final captured = verify(
      () => harness.api.postTicketMessage(
        captureAny(),
        idempotencyKey: captureAny(named: 'idempotencyKey'),
      ),
    ).captured;
    final request = captured[0] as PostTicketMessageRequest;
    expect(request.ticketId, 'tkt_1');
    expect(request.body, 'Спасибо, жду перепечатку!');
    expect((captured[1] as String).isNotEmpty, isTrue);
    expect(find.text('Спасибо, жду перепечатку!'), findsOneWidget);
  });

  testWidgets('ошибка отправки возвращает текст в поле, а не теряет его', (
    tester,
  ) async {
    useTallViewport(tester);
    final harness = FunnelHarness();
    when(() => harness.api.supportTicket('tkt_1'))
        .thenAnswer((_) async => Ok<SupportTicket>(supportTicketFixture()));
    when(
      () => harness.api.postTicketMessage(
        any(),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer(
      (_) async => Err<SupportTicket>(
        const ApiFailure(
          code: ApiErrorCode.validationFailed,
          message: 'body out of range',
          statusCode: 422,
        ),
      ),
    );

    await harness.pump(tester);
    harness.go('${AppRoutes.support}/tkt_1');
    await harness.settle(tester);

    await sendReply(tester, 'Текст, который нельзя потерять');
    await harness.settle(tester);

    expect(
      find.textContaining('Не удалось отправить сообщение'),
      findsOneWidget,
    );
    final field = tester.widget<TextField>(
      find.byKey(const Key('support-reply')),
    );
    expect(field.controller?.text, 'Текст, который нельзя потерять');
  });

  testWidgets('офлайн-ответ попадает в очередь с сохранённым ключом', (
    tester,
  ) async {
    useTallViewport(tester);
    final harness = FunnelHarness();
    when(() => harness.api.supportTicket('tkt_1'))
        .thenAnswer((_) async => Ok<SupportTicket>(supportTicketFixture()));
    when(
      () => harness.api.postTicketMessage(
        any(),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer(
      (_) async => Err<SupportTicket>(ApiFailure.networkUnavailable()),
    );

    await harness.pump(tester);
    harness.go('${AppRoutes.support}/tkt_1');
    await harness.settle(tester);

    await sendReply(tester, 'Напишу, когда появится сеть');
    await harness.settle(tester);

    expect(find.text('В очереди'), findsWidgets);

    final store = PendingActionsStore(
      database: harness.database,
      clock: harness.clock,
    );
    final rows = await store.all();
    expect(rows, hasLength(1));
    expect(rows.single.kind, PendingActionKind.postMessage);
    expect(rows.single.idempotencyKey, isNotEmpty);
    expect(rows.single.attempts, 0);

    final captured = verify(
      () => harness.api.postTicketMessage(
        captureAny(),
        idempotencyKey: captureAny(named: 'idempotencyKey'),
      ),
    ).captured;
    expect(rows.single.idempotencyKey, captured[1] as String);
  });

  testWidgets('чужой тикет — понятная ошибка, а не пустой экран', (
    tester,
  ) async {
    useTallViewport(tester);
    final harness = FunnelHarness();
    when(() => harness.api.supportTicket('tkt_foreign')).thenAnswer(
      (_) async => Err<SupportTicket>(
        const ApiFailure(
          code: ApiErrorCode.forbidden,
          message: 'the ticket belongs to another customer',
          statusCode: 403,
        ),
      ),
    );

    await harness.pump(tester);
    harness.go('${AppRoutes.support}/tkt_foreign');
    await harness.settle(tester);

    expect(find.text('Это обращение другого клиента'), findsOneWidget);
    expect(
      find.text('Показать его могут только автор и поддержка.'),
      findsOneWidget,
    );
    expect(harness.tokens.session?.role, UserRole.customer);
  });

  testWidgets('создание обращения привязывается к заказу клиента', (
    tester,
  ) async {
    useTallViewport(tester);
    final harness = FunnelHarness();
    when(() => harness.api.supportTickets())
        .thenAnswer((_) async => Ok<List<SupportTicket>>(<SupportTicket>[]));
    when(() => harness.api.orders(limit: any(named: 'limit'))).thenAnswer(
      (_) async => Ok<OrderHistoryPage>(
        OrderHistoryPage(orders: <Order>[orderFixture()], nextCursor: null),
      ),
    );
    when(
      () => harness.api.createSupportTicket(
        any(),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer(
      (_) async => Ok<SupportTicket>(
        supportTicketFixture(orderId: 'ord_1', subject: 'Полоса на фото'),
      ),
    );

    await harness.pump(tester);
    harness.go(AppRoutes.support);
    await harness.settle(tester);

    await tester.tap(find.byTooltip('Новое обращение'));
    await harness.settle(tester);

    await tester.enterText(
      find.byKey(const Key('ticket-subject')),
      'Полоса на фото',
    );
    await tester.enterText(
      find.byKey(const Key('ticket-body')),
      'На двух снимках полоса по краю.',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('ticket-order')));
    await harness.settle(tester);
    await tester.tap(find.textContaining('PP-1001').last);
    await harness.settle(tester);

    await tester.tap(find.text('Создать обращение'));
    await harness.settle(tester);

    final captured = verify(
      () => harness.api.createSupportTicket(
        captureAny(),
        idempotencyKey: captureAny(named: 'idempotencyKey'),
      ),
    ).captured;
    final request = captured[0] as CreateTicketRequest;
    expect(request.orderId, 'ord_1');
    expect(request.type, TicketType.question);
    expect(request.subject, 'Полоса на фото');
    expect((captured[1] as String).isNotEmpty, isTrue);
    expect(find.text('Обращение создано'), findsOneWidget);
  });

  testWidgets('агент отвечает в обращении клиента', (tester) async {
    useTallViewport(tester);
    final harness = FunnelHarness(role: UserRole.supportAgent);
    when(() => harness.api.supportTicket('tkt_1'))
        .thenAnswer((_) async => Ok<SupportTicket>(supportTicketFixture()));
    when(
      () => harness.api.postTicketMessage(
        any(),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer(
      (_) async => Ok<SupportTicket>(
        supportTicketFixture(
          status: TicketStatus.pending,
          messages: <TicketMessage>[
            ticketMessageFixture(),
            ticketMessageFixture(
              id: 'msg_2',
              author: UserRole.supportAgent,
              body: 'Перепечатаем и пришлём заново.',
            ),
          ],
        ),
      ),
    );

    await harness.pump(tester);
    harness.go('${AppRoutes.support}/tkt_1');
    await harness.settle(tester);

    await sendReply(tester, 'Перепечатаем и пришлём заново.');
    await harness.settle(tester);

    expect(find.text('Перепечатаем и пришлём заново.'), findsOneWidget);
    expect(find.text('Ответ клиенту'), findsOneWidget);
    verify(
      () => harness.api.postTicketMessage(
        any(),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).called(1);
  });
}
