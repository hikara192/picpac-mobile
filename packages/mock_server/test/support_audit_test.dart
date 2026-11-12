import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  late MockApi api;
  late String customerToken;
  late String supportToken;
  late Map<String, Object?> order;

  setUp(() async {
    api = MockApi();
    customerToken = await api.login();
    supportToken = await api.loginSupport();
    order = await api.placeOrder(customerToken);
  });

  Future<MockResponse> createTicket(
    String body, {
    String? token,
    String idempotencyKey = 'ticket-key-1',
    String? orderId,
  }) => api.call(
    'POST',
    '/v1/support/tickets',
    token: token ?? customerToken,
    headers: <String, String>{'idempotency-key': idempotencyKey},
    body: <String, Object?>{
      'subject': 'Проблема с заказом',
      'body': body,
      'type': 'defect',
      'orderId': ?orderId,
    },
  );

  group('support tickets', () {
    test('a customer creates a ticket and support replies', () async {
      final created = await createTicket(
        'Один отпечаток пришёл с царапиной',
        orderId: order['id']! as String,
      );
      expect(created.status, 201, reason: created.text);
      final ticket = SupportTicket.fromJson(created.object);
      expect(ticket.status, TicketStatus.open);
      expect(ticket.type, TicketType.defect);
      expect(ticket.orderId, order['id']);
      expect(ticket.messages.single.isFromCustomer, isTrue);

      final list = await api.call(
        'GET',
        '/v1/support/tickets',
        token: customerToken,
      );
      expect(
        SupportTicket.fromJson((list.list.single! as Map).cast()).id,
        ticket.id,
      );

      final reply = await api.call(
        'POST',
        '/v1/support/tickets/${ticket.id}/messages',
        token: supportToken,
        headers: <String, String>{'idempotency-key': 'reply-1'},
        body: <String, Object?>{
          'ticketId': ticket.id,
          'body': 'Перевыпустим отпечаток, извините',
        },
      );
      expect(reply.status, 200, reason: reply.text);
      final afterReply = SupportTicket.fromJson(reply.object);
      expect(afterReply.status, TicketStatus.pending);
      expect(afterReply.messages, hasLength(2));
      expect(afterReply.messages.last.authorRole, UserRole.supportAgent);

      final customerView = await api.call(
        'GET',
        '/v1/support/tickets/${ticket.id}',
        token: customerToken,
      );
      expect(
        SupportTicket.fromJson(customerView.object).messages,
        hasLength(2),
      );
    });

    test('a customer cannot see or write into another ticket', () async {
      final created = SupportTicket.fromJson(
        (await createTicket('Свой тикет')).object,
      );
      final other = api.registerCustomer('cus_other');

      final foreignTicket = await api.call(
        'GET',
        '/v1/support/tickets/${created.id}',
        token: other,
      );
      expectError(foreignTicket, 403, ApiErrorCode.forbidden);

      final foreignReply = await api.call(
        'POST',
        '/v1/support/tickets/${created.id}/messages',
        token: other,
        headers: <String, String>{'idempotency-key': 'foreign-reply'},
        body: <String, Object?>{'ticketId': created.id, 'body': 'чужой ответ'},
      );
      expectError(foreignReply, 403, ApiErrorCode.forbidden);

      final foreignList = await api.call(
        'GET',
        '/v1/support/tickets',
        token: other,
      );
      expect(foreignList.list, isEmpty);
    });

    test('support sees every ticket', () async {
      await createTicket('Первый');
      final other = api.registerCustomer('cus_other');
      await createTicket('Второй', token: other, idempotencyKey: 'ticket-2');

      final all = await api.call(
        'GET',
        '/v1/support/tickets',
        token: supportToken,
      );
      expect(all.list, hasLength(2));
    });

    test('guest sessions cannot open tickets', () async {
      final guest = await api.anonymous();
      final response = await createTicket('Гость', token: guest);
      expectError(response, 403, ApiErrorCode.forbidden);
    });

    test('a ticket can only reference an own order', () async {
      final other = api.registerCustomer('cus_other');
      final response = await createTicket(
        'Чужой заказ',
        token: other,
        orderId: order['id']! as String,
      );
      expectError(response, 403, ApiErrorCode.forbidden);
    });
  });

  group('audit', () {
    test('a customer cannot read the audit log', () async {
      final response = await api.call('GET', '/v1/audit', token: customerToken);
      expectError(response, 403, ApiErrorCode.forbidden);
    });

    test('support reads the log and can filter it', () async {
      await createTicket('Тикет для аудита', orderId: order['id']! as String);

      final all = await api.call(
        'GET',
        '/v1/audit?limit=100',
        token: supportToken,
      );
      expect(all.status, 200, reason: all.text);
      final records = <AuditRecord>[
        for (final raw in all.list)
          AuditRecord.fromJson((raw! as Map).cast<String, Object?>()),
      ];
      final actions = records.map((record) => record.action).toSet();
      expect(
        actions,
        containsAll(<String>['auth.login', 'order.create', 'ticket.create']),
      );
      expect(records.every((record) => record.at.isUtc), isTrue);

      final filtered = await api.call(
        'GET',
        '/v1/audit?objectType=order&limit=10',
        token: supportToken,
      );
      final onlyOrders = <AuditRecord>[
        for (final raw in filtered.list)
          AuditRecord.fromJson((raw! as Map).cast<String, Object?>()),
      ];
      expect(onlyOrders, isNotEmpty);
      expect(
        onlyOrders.every((record) => record.objectType == 'order'),
        isTrue,
      );

      final byActor = await api.call(
        'GET',
        '/v1/audit?actorId=cus_demo&limit=100',
        token: supportToken,
      );
      expect(byActor.list, isNotEmpty);
    });

    test('records every mutating action and never leaks PII', () async {
      final design = await api.createPrintDesign(customerToken);
      await api.addToCart(customerToken, design['id']! as String, quantity: 2);
      await createTicket(
        'Тело сообщения с телефоном +375291234567',
        orderId: order['id']! as String,
      );

      final response = await api.call(
        'GET',
        '/v1/audit?limit=200',
        token: supportToken,
      );
      final rawText = response.text;
      expect(response.status, 200);
      final actions = <AuditRecord>[
        for (final raw in response.list)
          AuditRecord.fromJson((raw! as Map).cast<String, Object?>()),
      ].map((record) => record.action).toSet();
      expect(
        actions,
        containsAll(<String>[
          'design.create',
          'cart.item_add',
          'order.create',
          'ticket.create',
        ]),
      );

      expect(rawText, contains('***4567'));
      expect(rawText, isNot(contains('375291234567')));
      expect(rawText, isNot(contains('Тело сообщения')));
      expect(rawText, isNot(contains('Проблема с заказом')));

      final orderRecord = <AuditRecord>[
        for (final raw in response.list)
          AuditRecord.fromJson((raw! as Map).cast<String, Object?>()),
      ].firstWhere((record) => record.action == 'order.create');
      expect(orderRecord.details['contactPhone'], '***4567');
      expect(orderRecord.actorId, 'cus_demo');
      expect(orderRecord.actorRole, ActorRole.customer);
    });
  });
}
