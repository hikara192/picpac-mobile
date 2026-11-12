import 'package:api_contract/api_contract.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:uuid/uuid.dart';

import '../context.dart';
import '../errors.dart';
import '../mock_server.dart';
import '../records.dart';
import '../security.dart';
import '../serialization.dart';

void registerAuthRoutes(Router router, MockServer server) {
  router.post('/v1/auth/anonymous', (Request request) async {
    final ctx = contextOf(request);
    final body = await ctx.jsonBody();
    final parsed = AnonymousSessionRequest.fromJson(body);

    final customer = server.createGuest();
    final issued = server.issueSession(customer);
    ctx.audit(
      action: 'auth.anonymous',
      objectType: 'customer',
      objectId: customer.id,
      details: <String, Object?>{'locale': parsed.locale},
    );
    return ctx.json(
      authSessionJson(
        session: issued.session,
        customer: customer,
        token: issued.token,
      ),
    );
  });

  router.post('/v1/auth/login', (Request request) async {
    final ctx = contextOf(request);
    final parsed = LoginRequest.fromJson(await ctx.jsonBody());

    final email = parsed.email.trim().toLowerCase();
    final bucket =
        'login|${email.length > 254 ? email.substring(0, 254) : email}';
    final lock = server.lockRemaining(bucket);
    if (lock != null) throw ApiException.rateLimited(lock);

    final account = server.seeds.accounts.byEmail(parsed.email);
    final registered = server.registeredAccounts[email];
    final passwordMatches = pbkdf2Verify(
      parsed.password,
      account?.passwordHash ??
          server.registeredHashes[email] ??
          dummyPasswordHash,
    );
    final valid = (account != null || registered != null) && passwordMatches;
    if (!valid) {
      server.recordFailure(bucket, maxAttempts: loginMaxFailures);
      ctx.audit(
        action: 'auth.login',
        objectType: 'customer',
        objectId: 'unknown',
        result: 'denied',
        actorRole: ActorRole.system,
        details: <String, Object?>{'reason': 'invalid_credentials'},
      );
      throw ApiException.unauthorized('invalid email or password');
    }
    server.clearFailures(bucket);

    final customer = account == null
        ? registered
        : server.customerById(account.id);
    if (customer == null || customer.deleted) {
      throw ApiException.unauthorized('the account is no longer available');
    }
    final issued = server.issueSession(customer);
    ctx.audit(
      action: 'auth.login',
      objectType: 'customer',
      objectId: customer.id,
      actorRole: customer.role == UserRole.supportAgent
          ? ActorRole.supportAgent
          : ActorRole.customer,
      actorId: customer.id,
      details: <String, Object?>{'role': customer.role.wire},
    );
    return ctx.json(
      authSessionJson(
        session: issued.session,
        customer: customer,
        token: issued.token,
      ),
    );
  });

  router.post('/v1/auth/register', (Request request) async {
    final ctx = contextOf(request);
    final body = await ctx.jsonBody();
    final email = (body['email'] as String? ?? '').trim().toLowerCase();
    final password = body['password'] as String? ?? '';
    final name = (body['name'] as String? ?? '').trim();
    if (!email.contains('@') || email.length < 5) {
      throw ApiException.validation(
        'a valid email is required',
        fieldErrors: const <String, String>{'email': 'invalid'},
      );
    }
    if (password.length < 8) {
      throw ApiException.validation(
        'the password must be at least 8 characters',
        fieldErrors: const <String, String>{'password': 'too_short'},
      );
    }
    if (server.seeds.accounts.byEmail(email) != null ||
        server.registeredAccounts.containsKey(email)) {
      throw ApiException.conflict('email_taken', 'this email is already used');
    }
    final id = 'cus_${const Uuid().v4()}';
    final record = CustomerRecord(
      id: id,
      createdAt: server.clock.now(),
      role: UserRole.customer,
      isGuest: false,
      name: name.isEmpty ? email.split('@').first : name,
      email: email,
    );
    server.customers[id] = record;
    server.registeredAccounts[email] = record;
    server.registeredHashes[email] = pbkdf2Hash(password);
    final issued = server.issueSession(record);
    ctx.audit(
      action: 'auth.register',
      objectType: 'customer',
      objectId: id,
      actorId: id,
      actorRole: ActorRole.customer,
      details: const <String, Object?>{'role': 'customer'},
    );
    return ctx.json(
      authSessionJson(
        session: issued.session,
        customer: record,
        token: issued.token,
      ),
    );
  });

  router.post('/v1/auth/verify', (Request request) async {
    final ctx = contextOf(request);
    final body = await ctx.jsonBody();
    final challengeId = body['challengeId'];
    final code = body['code'];
    if (challengeId is! String || challengeId.trim().isEmpty) {
      throw ApiException.validation(
        'challengeId is required',
        fieldErrors: <String, String>{'challengeId': 'required'},
      );
    }
    if (code is! String || code.trim().isEmpty) {
      throw ApiException.validation(
        'code is required',
        fieldErrors: <String, String>{'code': 'required'},
      );
    }

    final challenge = server.challenges[challengeId];
    if (challenge == null) {
      if (server.challengeBurned(challengeId)) {
        throw ApiException(
          410,
          'challenge_expired',
          'the challenge was completed or burned; request a new code',
        );
      }
      throw ApiException.notFound('the challenge is unknown or expired');
    }
    if (challenge.isExpiredAt(server.clock.now())) {
      server.burnChallenge(challengeId);
      throw ApiException(
        410,
        'challenge_expired',
        'the challenge has expired; request a new code',
      );
    }
    if (!constantTimeEquals(challenge.code, code.trim())) {
      final burned = server.recordChallengeFailure(challengeId);
      ctx.audit(
        action: 'auth.verify',
        objectType: 'challenge',
        objectId: challengeId,
        result: 'denied',
        actorRole: ActorRole.system,
        details: <String, Object?>{'reason': 'invalid_code', 'burned': burned},
      );
      if (burned) {
        throw ApiException(
          410,
          'challenge_expired',
          'too many wrong codes; the challenge is burned, request a new code',
        );
      }
      throw ApiException.validation(
        'the verification code is invalid',
        fieldErrors: <String, String>{'code': 'invalid_code'},
      );
    }
    server.burnChallenge(challengeId);
    final customer = server.customerById(challenge.accountId);
    if (customer == null || customer.deleted) {
      throw ApiException.unauthorized('the account is no longer available');
    }
    final issued = server.issueSession(customer);
    ctx.audit(
      action: 'auth.verify',
      objectType: 'customer',
      objectId: customer.id,
      actorId: customer.id,
      details: <String, Object?>{'role': customer.role.wire},
    );
    return ctx.json(
      authSessionJson(
        session: issued.session,
        customer: customer,
        token: issued.token,
      ),
    );
  });

  router.get('/v1/me', (Request request) {
    final ctx = contextOf(request);
    final customer = ctx.requireUser();
    return ctx.json(customer.toDto().toJson());
  });

  router.delete('/v1/me', (Request request) {
    final ctx = contextOf(request);
    final customer = ctx.requireUser();
    final summary = cascadeDelete(server, customer);
    ctx.audit(
      action: 'account.delete',
      objectType: 'customer',
      objectId: MockServer.anonymizedActorId(customer.id),
      actorId: MockServer.anonymizedActorId(customer.id),
      details: summary,
    );
    return ctx.noContent();
  });
}

Map<String, Object?> cascadeDelete(MockServer server, CustomerRecord customer) {
  final customerId = customer.id;
  final anonymized = MockServer.anonymizedActorId(customerId);

  final designIds = <String>{};
  for (final design in server.designs.values.toList()) {
    if (design.ownerId == customerId) designIds.add(design.id);
  }
  final orderIds = <String>{};
  for (final order in server.orders.values.toList()) {
    if (order.ownerId == customerId) orderIds.add(order.id);
  }
  final ticketIds = <String>{};
  for (final ticket in server.tickets.values.toList()) {
    if (ticket.ownerId == customerId) ticketIds.add(ticket.id);
  }
  final uploadIds = <String>{};
  for (final upload in server.uploads.values.toList()) {
    if (upload.ownerId == customerId) uploadIds.add(upload.id);
  }

  for (final session in server.sessions.values) {
    if (session.customerId == customerId) session.revoked = true;
  }
  server.sessions.removeWhere((_, session) => session.customerId == customerId);

  for (final id in designIds) {
    server.designs.remove(id);
  }
  server.carts.remove(customerId);
  for (final cart in server.carts.values) {
    cart.lines.removeWhere((line) => designIds.contains(line.designId));
  }

  for (final id in orderIds) {
    final order = server.orders.remove(id);
    if (order == null) continue;
    final intentId = order.latestIntentId;
    if (intentId != null) server.intents.remove(intentId);
    for (final refund in order.refunds) {
      server.refunds.remove(refund.id);
    }
  }
  server.intents.removeWhere((_, intent) => orderIds.contains(intent.orderId));
  server.receipts.removeWhere(
    (_, receipt) => orderIds.contains(receipt.orderId),
  );
  server.refunds.removeWhere((_, refund) => orderIds.contains(refund.orderId));

  for (final id in ticketIds) {
    server.tickets.remove(id);
  }
  for (final id in uploadIds) {
    server.uploads.remove(id);
  }

  server.customers[customerId] = CustomerRecord(
    id: customerId,
    createdAt: customer.createdAt,
    role: customer.role,
    isGuest: customer.isGuest,
    deleted: true,
  );

  for (var i = 0; i < server.auditLength; i++) {
    final entry = server.auditAt(i);
    if (entry.actorId != customerId &&
        entry.details['customerId'] != customerId) {
      continue;
    }
    server.replaceAudit(
      i,
      AuditRecordEntry(
        id: entry.id,
        at: entry.at,
        action: entry.action,
        objectType: entry.objectType,
        objectId: entry.objectId == customerId || entry.objectId == anonymized
            ? anonymized
            : entry.objectId,
        result: entry.result,
        actorRole: entry.actorRole,
        actorId: entry.actorId == null ? null : anonymized,
        details: <String, Object?>{
          for (final detail in entry.details.entries)
            if (detail.key != 'customerId' &&
                detail.key != 'phone' &&
                detail.key != 'email')
              detail.key: detail.value,
        },
      ),
    );
  }
  server.forgetIdempotency(customerId);
  server.forgetFavorites(customerId);

  return <String, Object?>{
    'designs': designIds.length,
    'orders': orderIds.length,
    'tickets': ticketIds.length,
    'uploads': uploadIds.length,
  };
}
