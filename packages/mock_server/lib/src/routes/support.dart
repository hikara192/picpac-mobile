import 'package:api_contract/api_contract.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../context.dart';
import '../errors.dart';
import '../mock_server.dart';
import '../records.dart';
import 'orders.dart';

void registerSupportRoutes(Router router, MockServer server) {
  router.get('/v1/support/tickets', (Request request) {
    final ctx = contextOf(request);
    final session = ctx.requireSession();
    final customer = ctx.requireUser();
    final query = request.url.queryParameters;
    final orderId = query['orderId'];
    final status = query['status'];

    final visible =
        server.tickets.values
            .where(
              (ticket) =>
                  session.role == UserRole.supportAgent ||
                  ticket.ownerId == customer.id,
            )
            .where((ticket) => orderId == null || ticket.orderId == orderId)
            .where((ticket) => status == null || ticket.status.wire == status)
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return ctx.json(<Object?>[
      for (final ticket in visible) ticket.toDto().toJson(),
    ]);
  });

  router.post('/v1/support/tickets', (Request request) async {
    final ctx = contextOf(request);
    final session = ctx.requireSession();
    final customer = ctx.requireUser(allowGuest: false);
    final key = requireIdempotencyKey(ctx);
    final body = await ctx.jsonBody();
    final parsed = CreateTicketRequest.fromJson(body);

    final stored = server.idempotency('tickets', customer.id, key);
    if (stored != null) {
      final bodyHash = MockServer.bodyHash(await ctx.bodyText());
      if (bodyHash != stored.bodyHash) {
        throw ApiException(
          422,
          ApiErrorCode.idempotencyConflict,
          'the same Idempotency-Key was used with a different request body',
        );
      }
      final ticket = server.tickets[stored.resultId];
      if (ticket == null) throw ApiException.notFound('the ticket is gone');
      return ctx.json(ticket.toDto().toJson());
    }

    final subject = parsed.subject.trim();
    if (subject.isEmpty || subject.length > 200) {
      throw ApiException.validation(
        'subject must be within 1..200 characters',
        fieldErrors: const <String, String>{'subject': 'out_of_range'},
      );
    }
    final text = parsed.body.trim();
    if (text.isEmpty || text.length > 4000) {
      throw ApiException.validation(
        'body must be within 1..4000 characters',
        fieldErrors: const <String, String>{'body': 'out_of_range'},
      );
    }
    if (parsed.type == TicketType.unknown) {
      throw ApiException.validation(
        'unknown ticket type',
        fieldErrors: const <String, String>{'type': 'unknown_type'},
      );
    }
    final orderId = parsed.orderId;
    if (orderId != null) {
      final order = server.orders[orderId];
      if (order == null) throw ApiException.notFound('unknown order');
      final allowed =
          session.role == UserRole.supportAgent ||
          order.accessibleBy(customer.id);
      if (!allowed) {
        ctx.audit(
          action: 'ticket.create',
          objectType: 'order',
          objectId: orderId,
          result: 'denied',
          details: const <String, Object?>{'reason': 'foreign_order'},
        );
        throw ApiException.forbidden('the order belongs to another customer');
      }
    }

    final now = server.clock.now();
    final id = server.nextId('tkt');
    final ticket =
        TicketRecord(
            id: id,
            ownerId: customer.id,
            subject: subject,
            type: parsed.type,
            orderId: orderId,
            createdAt: now,
          )
          ..messages.add(
            TicketMessageRecord(
              id: server.nextId('msg'),
              authorRole: session.role,
              body: text,
              createdAt: now,
              attachments: parsed.attachments,
            ),
          );
    server.tickets[id] = ticket;
    server.rememberIdempotency(
      IdempotencyRecord(
        key: key,
        endpoint: 'tickets',
        bodyHash: MockServer.bodyHash(await ctx.bodyText()),
        customerId: customer.id,
        resultType: 'ticket',
        resultId: id,
      ),
    );
    ctx.audit(
      action: 'ticket.create',
      objectType: 'ticket',
      objectId: id,
      details: <String, Object?>{
        'orderId': orderId,
        'type': parsed.type.wire,
        'attachments': parsed.attachments.length,
      },
    );
    return ctx.json(ticket.toDto().toJson(), status: 201);
  });

  router.get('/v1/support/tickets/<ticketId>', (
    Request request,
    String ticketId,
  ) {
    final ctx = contextOf(request);
    ctx.requireSession();
    final ticket = _visibleTicket(ctx, ticketId);
    return ctx.json(ticket.toDto().toJson());
  });

  router.post('/v1/support/tickets/<ticketId>/messages', (
    Request request,
    String ticketId,
  ) async {
    final ctx = contextOf(request);
    final session = ctx.requireSession();
    final customer = ctx.requireUser(allowGuest: false);
    final key = requireIdempotencyKey(ctx);
    final body = await ctx.jsonBody();
    final parsed = PostTicketMessageRequest.fromJson(body);

    final stored = server.idempotency('ticket-messages', customer.id, key);
    if (stored != null) {
      final bodyHash = MockServer.bodyHash(await ctx.bodyText());
      if (bodyHash != stored.bodyHash) {
        throw ApiException(
          422,
          ApiErrorCode.idempotencyConflict,
          'the same Idempotency-Key was used with a different request body',
        );
      }
      final ticket = server.tickets[stored.resultId];
      if (ticket == null) throw ApiException.notFound('the ticket is gone');
      return ctx.json(ticket.toDto().toJson());
    }

    final ticket = _visibleTicket(ctx, ticketId);
    if (ticket.status == TicketStatus.closed ||
        ticket.status == TicketStatus.resolved) {
      throw ApiException.conflict(
        'ticket_closed',
        'the ticket is closed and accepts no new messages',
      );
    }
    if (parsed.ticketId != ticketId) {
      throw ApiException.validation(
        'ticketId does not match the path',
        fieldErrors: const <String, String>{'ticketId': 'path_mismatch'},
      );
    }
    final text = parsed.body.trim();
    if (text.isEmpty || text.length > 4000) {
      throw ApiException.validation(
        'body must be within 1..4000 characters',
        fieldErrors: const <String, String>{'body': 'out_of_range'},
      );
    }

    final now = server.clock.now();
    final message = TicketMessageRecord(
      id: server.nextId('msg'),
      authorRole: session.role,
      body: text,
      createdAt: now,
      attachments: parsed.attachments,
    );
    ticket
      ..messages.add(message)
      ..updatedAt = now
      ..status = session.role == UserRole.supportAgent
          ? TicketStatus.pending
          : TicketStatus.open;
    server.rememberIdempotency(
      IdempotencyRecord(
        key: key,
        endpoint: 'ticket-messages',
        bodyHash: MockServer.bodyHash(await ctx.bodyText()),
        customerId: customer.id,
        resultType: 'ticket',
        resultId: ticket.id,
      ),
    );
    ctx.audit(
      action: 'ticket.reply',
      objectType: 'ticket',
      objectId: ticket.id,
      details: <String, Object?>{
        'authorRole': session.role.wire,
        'attachments': parsed.attachments.length,
        'messageCount': ticket.messages.length,
      },
    );
    return ctx.json(ticket.toDto().toJson());
  });
}

TicketRecord _visibleTicket(MockContext ctx, String ticketId) {
  final ticket = ctx.server.tickets[ticketId];
  if (ticket == null) throw ApiException.notFound('unknown ticket');
  final session = ctx.session!;
  if (session.role == UserRole.supportAgent) return ticket;
  if (ticket.ownerId != session.customerId) {
    ctx.audit(
      action: 'ticket.access',
      objectType: 'ticket',
      objectId: ticketId,
      result: 'denied',
      details: const <String, Object?>{'reason': 'foreign_ticket'},
    );
    throw ApiException.forbidden('the ticket belongs to another customer');
  }
  return ticket;
}
