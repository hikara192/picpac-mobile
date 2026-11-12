import 'package:api_contract/api_contract.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../context.dart';
import '../errors.dart';
import '../mock_server.dart';
import '../records.dart';
import '../security.dart';
import 'orders.dart';

const Map<String, Set<String>> paymentTransitions = <String, Set<String>>{
  'created': <String>{
    'requires_action',
    'pending_user',
    'processing',
    'succeeded',
    'failed',
    'canceled',
    'expired',
  },
  'requires_action': <String>{
    'processing',
    'succeeded',
    'failed',
    'canceled',
    'expired',
  },
  'pending_user': <String>{
    'processing',
    'succeeded',
    'failed',
    'expired',
    'canceled',
  },
  'processing': <String>{'succeeded', 'failed', 'expired'},
  'pending_on_delivery': <String>{'succeeded', 'failed'},
  'succeeded': <String>{'refunded', 'partially_refunded'},
  'partially_refunded': <String>{'refunded'},
  'failed': <String>{},
  'expired': <String>{},
  'canceled': <String>{},
  'refunded': <String>{},
};

void registerPaymentRoutes(Router router, MockServer server) {
  router.get('/v1/payments/methods', (Request request) {
    final ctx = contextOf(request);
    final regionCode = request.url.queryParameters['region'] ?? 'BY';
    final region = server.seeds.payments.regionByCode(regionCode);
    if (region == null) {
      throw ApiException.validation(
        'unknown region',
        fieldErrors: const <String, String>{'region': 'unknown_region'},
      );
    }
    return ctx.json(<Object?>[
      for (final method in region.methods) method.toDto(region).toJson(),
    ]);
  });

  router.post('/v1/orders/<orderId>/payment-intent', (
    Request request,
    String orderId,
  ) async {
    final ctx = contextOf(request);
    final customer = ctx.requireCustomer();
    final key = requireIdempotencyKey(ctx);
    final parsed = CreatePaymentIntentRequest.fromJson(await ctx.jsonBody());
    if (parsed.orderId != orderId) {
      throw ApiException.validation(
        'orderId does not match the path',
        fieldErrors: const <String, String>{'orderId': 'path_mismatch'},
      );
    }
    final order = server.orders[orderId];
    if (order == null) throw ApiException.notFound('unknown order');
    if (!order.accessibleBy(customer.id)) {
      ctx.audit(
        action: 'payment.intent_create',
        objectType: 'order',
        objectId: orderId,
        result: 'denied',
        details: const <String, Object?>{'reason': 'foreign_order'},
      );
      throw ApiException.forbidden('the order belongs to another customer');
    }

    final stored = server.idempotency('payment-intent', customer.id, key);
    if (stored != null) {
      final bodyHash = MockServer.bodyHash(await ctx.bodyText());
      if (bodyHash != stored.bodyHash) {
        throw ApiException(
          422,
          ApiErrorCode.idempotencyConflict,
          'the same Idempotency-Key was used with a different request body',
        );
      }
      final intent = server.intents[stored.resultId];
      if (intent == null) throw ApiException.notFound('the intent is gone');
      return ctx.json(intent.toJson());
    }

    if (order.isPaid) {
      throw ApiException.conflict(
        'payment_already_paid',
        'the order is already paid; a refund is the next step, not a new intent',
      );
    }
    if (order.paymentStatus == 'refunded' ||
        order.paymentStatus == 'partially_refunded') {
      throw ApiException.conflict(
        'payment_already_paid',
        'the order was paid and refunded',
      );
    }
    if (order.fulfillmentStatus == 'canceled' ||
        order.fulfillmentStatus == 'returned') {
      throw ApiException.conflict(
        'order_not_payable',
        'a canceled or returned order cannot be paid',
      );
    }
    if (order.totalMinor == 0) {
      throw ApiException.conflict(
        'payment_not_required',
        'the order total is 0; a 100 % promo order needs no payment intent',
      );
    }

    final regionCode = (parsed.region ?? server.seeds.catalog.region)
        .toUpperCase();
    final region = server.seeds.payments.regionByCode(regionCode);
    if (region == null) {
      throw ApiException.validation(
        'unknown region',
        fieldErrors: const <String, String>{'region': 'unknown_region'},
      );
    }
    if (region.currency != order.currency) {
      throw ApiException.validation(
        'the payment region charges in another currency',
        fieldErrors: const <String, String>{'region': 'currency_mismatch'},
      );
    }
    final method = region.methodById(parsed.methodId);
    if (method == null) {
      throw ApiException.validation(
        'unknown payment method for the region',
        fieldErrors: const <String, String>{'methodId': 'unknown_method'},
      );
    }

    final now = server.clock.now();
    for (final existing in server.intents.values) {
      if (existing.orderId != order.id) continue;
      if (existing.isPending && !_isExpired(existing, now)) {
        server.rememberIdempotency(
          IdempotencyRecord(
            key: key,
            endpoint: 'payment-intent',
            bodyHash: MockServer.bodyHash(await ctx.bodyText()),
            customerId: customer.id,
            resultType: 'intent',
            resultId: existing.id,
          ),
        );
        return ctx.json(existing.toJson());
      }
      if (existing.isPending) {
        applyPaymentStatus(server, existing, 'expired');
      }
    }

    final id = server.nextId('int');
    final intent = IntentRecord(
      id: id,
      orderId: order.id,
      provider: method.kind == 'cod' ? 'mock_psp' : region.provider,
      methodId: method.id,
      amountMinor: order.totalMinor,
      currency: order.currency,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 30)),
      status: switch (method.kind) {
        'cod' => 'pending_on_delivery',
        'sbp' => 'pending_user',
        _ => 'requires_action',
      },
      hostedPageUrl: method.kind == 'cod' ? null : _hostedUrl(ctx, id),
      qrPayload: method.kind == 'sbp' ? 'sbp://mock.picpac.local/$id' : null,
    );
    server.intents[id] = intent;
    order
      ..latestIntentId = id
      ..paymentStatus = intent.status;
    server.rememberIdempotency(
      IdempotencyRecord(
        key: key,
        endpoint: 'payment-intent',
        bodyHash: MockServer.bodyHash(await ctx.bodyText()),
        customerId: customer.id,
        resultType: 'intent',
        resultId: id,
      ),
    );
    ctx.audit(
      action: 'payment.intent_create',
      objectType: 'intent',
      objectId: id,
      details: <String, Object?>{
        'orderId': order.id,
        'methodId': method.id,
        'provider': intent.provider,
        'amountMinor': intent.amountMinor,
        'status': intent.status,
      },
    );
    return ctx.json(intent.toJson(), status: 201);
  });

  router.get('/v1/payments/<intentId>', (Request request, String intentId) {
    final ctx = contextOf(request);
    final session = ctx.requireSession();
    final customer = ctx.requireUser();
    final intent = server.intents[intentId];
    if (intent == null) throw ApiException.notFound('unknown payment intent');
    final order = server.orders[intent.orderId];
    if (order == null) throw ApiException.notFound('unknown order');
    if (session.role != UserRole.supportAgent &&
        !order.accessibleBy(customer.id)) {
      throw ApiException.forbidden('the payment belongs to another customer');
    }
    _expireIfNeeded(server, intent);
    return ctx.json(intent.toJson());
  });

  router.post('/v1/webhooks/psp/<provider>', (
    Request request,
    String provider,
  ) async {
    final ctx = contextOf(request);
    final raw = await ctx.bodyBytes();
    verifyPspWebhookSignature(ctx, raw);
    final body = await ctx.jsonBody();
    final eventId = body['eventId'];
    final intentId = body['intentId'];
    final type = body['type'];
    final fieldErrors = <String, String>{};
    if (eventId is! String || eventId.trim().isEmpty) {
      fieldErrors['eventId'] = 'required';
    }
    if (intentId is! String || intentId.trim().isEmpty) {
      fieldErrors['intentId'] = 'required';
    }
    if (type is! String || type.trim().isEmpty) {
      fieldErrors['type'] = 'required';
    }
    if (fieldErrors.isNotEmpty) {
      throw ApiException.validation(
        'invalid webhook payload',
        fieldErrors: fieldErrors,
      );
    }
    final intent = server.intents[intentId];
    if (intent == null) throw ApiException.notFound('unknown payment intent');
    if (intent.provider != provider) {
      throw ApiException.validation(
        'the webhook provider does not match the intent provider',
        fieldErrors: const <String, String>{'provider': 'mismatch'},
      );
    }

    final result = processWebhookEvent(
      server,
      provider: provider,
      eventId: eventId as String,
      intent: intent,
      type: (type as String).trim(),
    );
    ctx.audit(
      action: 'payment.webhook',
      objectType: 'intent',
      objectId: intent.id,
      actorRole: ActorRole.system,
      details: <String, Object?>{
        'provider': provider,
        'type': type,
        'duplicate': result.duplicate,
        'changed': result.changed,
        'status': intent.status,
      },
    );
    return ctx.json(<String, Object?>{
      'received': true,
      'duplicate': result.duplicate,
      'changed': result.changed,
      'status': intent.status,
    });
  });

  router.get('/v1/mock/psp/hosted/<intentId>', (
    Request request,
    String intentId,
  ) {
    final ctx = contextOf(request);
    final intent = server.intents[intentId];
    if (intent == null) throw ApiException.notFound('unknown payment intent');
    if (!server.verifyOpaque(intentId, request.url.queryParameters['token'])) {
      throw ApiException.forbidden('the hosted page token is invalid');
    }
    _expireIfNeeded(server, intent);
    final order = server.orders[intent.orderId];
    return ctx.html(hostedPaymentPage(intent, order));
  });

  router.post('/v1/mock/psp/hosted/<intentId>/pay', (
    Request request,
    String intentId,
  ) {
    final ctx = contextOf(request);
    final intent = server.intents[intentId];
    if (intent == null) throw ApiException.notFound('unknown payment intent');
    if (!server.verifyOpaque(intentId, request.url.queryParameters['token'])) {
      throw ApiException.forbidden('the hosted page token is invalid');
    }
    _expireIfNeeded(server, intent);
    final changed = applyPaymentStatus(server, intent, 'succeeded');
    ctx.audit(
      action: 'payment.hosted_pay',
      objectType: 'intent',
      objectId: intent.id,
      actorRole: ActorRole.system,
      details: <String, Object?>{'changed': changed, 'status': intent.status},
    );
    final order = server.orders[intent.orderId];
    return ctx.html(resultPage(intent, order, approved: true));
  });

  router.post('/v1/mock/psp/hosted/<intentId>/decline', (
    Request request,
    String intentId,
  ) {
    final ctx = contextOf(request);
    final intent = server.intents[intentId];
    if (intent == null) throw ApiException.notFound('unknown payment intent');
    if (!server.verifyOpaque(intentId, request.url.queryParameters['token'])) {
      throw ApiException.forbidden('the hosted page token is invalid');
    }
    _expireIfNeeded(server, intent);
    final changed = applyPaymentStatus(
      server,
      intent,
      'failed',
      failureCode: 'declined_by_user',
    );
    ctx.audit(
      action: 'payment.hosted_decline',
      objectType: 'intent',
      objectId: intent.id,
      actorRole: ActorRole.system,
      details: <String, Object?>{'changed': changed, 'status': intent.status},
    );
    final order = server.orders[intent.orderId];
    return ctx.html(resultPage(intent, order, approved: false));
  });

  if (server.mockControlsEnabled) {
    router.post('/v1/mock/psp/simulate', (Request request) async {
      final ctx = contextOf(request);
      ctx.requireMockControl();
      final body = await ctx.jsonBody();
      final scenario = body['scenario'];
      if (scenario is! String || scenario.isEmpty) {
        throw ApiException.validation(
          'scenario is required',
          fieldErrors: const <String, String>{'scenario': 'required'},
        );
      }
      final result = simulate(server, scenario, body);
      ctx.audit(
        action: 'payment.simulate',
        objectType: result.intent == null ? 'order' : 'intent',
        objectId: result.intent?.id ?? result.order?.id ?? 'unknown',
        actorRole: ActorRole.system,
        details: <String, Object?>{
          'scenario': scenario,
          'intentStatus': result.intent?.status,
          'paymentStatus': result.order?.paymentStatus,
        },
      );
      return ctx.json(<String, Object?>{
        'scenario': scenario,
        'intent': result.intent?.toJson(),
        'order': result.order?.toJson(),
      });
    });
  }

  router.post('/v1/orders/<orderId>/refunds', (
    Request request,
    String orderId,
  ) async {
    final ctx = contextOf(request);
    final session = ctx.requireSession();
    final customer = ctx.requireUser();
    final key = requireIdempotencyKey(ctx);
    final parsed = RefundRequest.fromJson(await ctx.jsonBody());
    if (parsed.orderId != orderId) {
      throw ApiException.validation(
        'orderId does not match the path',
        fieldErrors: const <String, String>{'orderId': 'path_mismatch'},
      );
    }
    final order = server.orders[orderId];
    if (order == null) throw ApiException.notFound('unknown order');
    if (session.role != UserRole.supportAgent) {
      ctx.audit(
        action: 'payment.refund',
        objectType: 'order',
        objectId: orderId,
        result: 'denied',
        details: const <String, Object?>{'reason': 'requires_support'},
      );
      throw Failures.refundNeedsSupport;
    }

    final stored = server.idempotency('refunds', customer.id, key);
    if (stored != null) {
      final bodyHash = MockServer.bodyHash(await ctx.bodyText());
      if (bodyHash != stored.bodyHash) {
        throw ApiException(
          422,
          ApiErrorCode.idempotencyConflict,
          'the same Idempotency-Key was used with a different request body',
        );
      }
      final refund = server.refunds[stored.resultId];
      if (refund == null) throw ApiException.notFound('the refund is gone');
      return ctx.json(refund.toDto().toJson());
    }

    if (!order.isPaid) {
      throw ApiException.conflict(
        'not_paid',
        'the order has no captured payment to refund',
      );
    }
    if (order.totalMinor <= 0) {
      throw ApiException(
        422,
        'nothing_to_refund',
        'the order total is 0; there is no captured money',
      );
    }
    final alreadyRefunded = order.refunds.fold<int>(
      0,
      (sum, refund) => sum + refund.amountMinor,
    );
    final remaining = order.totalMinor - alreadyRefunded;
    if (remaining <= 0) {
      throw ApiException.conflict(
        'already_refunded',
        'the order is fully refunded',
      );
    }
    if (parsed.amountMinor <= 0 || parsed.amountMinor > remaining) {
      throw ApiException.validation(
        'the refund amount must be within 1..$remaining',
        fieldErrors: const <String, String>{'amountMinor': 'out_of_range'},
      );
    }
    final intent = order.latestIntentId == null
        ? null
        : server.intents[order.latestIntentId];
    if (intent == null) {
      throw ApiException(
        422,
        'nothing_to_refund',
        'the order has no captured payment intent',
      );
    }

    final refund = RefundRecord(
      id: server.nextId('rfnd'),
      orderId: order.id,
      intentId: intent.id,
      amountMinor: parsed.amountMinor,
      currency: order.currency,
      status: 'succeeded',
      createdAt: server.clock.now(),
      reasonKey: parsed.reasonKey,
    );
    server.refunds[refund.id] = refund;
    order.refunds.add(refund);
    final totalRefunded = alreadyRefunded + refund.amountMinor;
    applyPaymentStatus(
      server,
      intent,
      totalRefunded >= order.totalMinor ? 'refunded' : 'partially_refunded',
    );
    server.rememberIdempotency(
      IdempotencyRecord(
        key: key,
        endpoint: 'refunds',
        bodyHash: MockServer.bodyHash(await ctx.bodyText()),
        customerId: customer.id,
        resultType: 'refund',
        resultId: refund.id,
      ),
    );
    ctx.audit(
      action: 'payment.refund',
      objectType: 'refund',
      objectId: refund.id,
      details: <String, Object?>{
        'orderId': order.id,
        'intentId': intent.id,
        'amountMinor': refund.amountMinor,
        'totalRefundedMinor': totalRefunded,
        'status': intent.status,
      },
    );
    return ctx.json(refund.toDto().toJson(), status: 201);
  });

  router.get('/v1/orders/<orderId>/receipt', (Request request, String orderId) {
    final ctx = contextOf(request);
    final session = ctx.requireSession();
    final customer = ctx.requireUser();
    final order = server.orders[orderId];
    if (order == null) throw ApiException.notFound('unknown order');
    if (session.role != UserRole.supportAgent &&
        !order.accessibleBy(customer.id)) {
      throw ApiException.forbidden('the order belongs to another customer');
    }
    if (!order.isPaid) {
      throw ApiException.conflict(
        'receipt_not_available',
        'a receipt exists only for a paid order',
      );
    }
    for (final receipt in server.receipts.values) {
      if (receipt.orderId == order.id) {
        return ctx.json(receipt.toDto().toJson());
      }
    }
    final id = server.nextId('rcp');
    final receipt = ReceiptRecord(
      id: id,
      orderId: order.id,
      fiscalId: 'FISC-${order.number}-${id.split('_').last}',
      amountMinor: order.totalMinor,
      currency: order.currency,
      issuedAt: server.clock.now(),
      url: '${ctx.origin}/v1/mock/receipts/$id',
    );
    server.receipts[id] = receipt;
    return ctx.json(receipt.toDto().toJson());
  });

  router.get('/v1/mock/receipts/<receiptId>', (
    Request request,
    String receiptId,
  ) {
    final ctx = contextOf(request);
    final receipt = server.receipts[receiptId];
    if (receipt == null) throw ApiException.notFound('unknown receipt');
    return ctx.html(receiptPage(receipt));
  });
}

bool applyPaymentStatus(
  MockServer server,
  IntentRecord intent,
  String target, {
  String? failureCode,
}) {
  if (intent.status == target) return false;
  final allowed = paymentTransitions[intent.status] ?? const <String>{};
  if (!allowed.contains(target)) return false;
  intent.status = target;
  if (failureCode != null) intent.failureCode = failureCode;
  final order = server.orders[intent.orderId];
  if (order != null) {
    order
      ..paymentStatus = target
      ..updatedAt = server.clock.now();
  }
  return true;
}

typedef WebhookOutcome = ({bool duplicate, bool changed});

void verifyPspWebhookSignature(MockContext ctx, List<int> rawBody) {
  final timestamp = ctx.header('x-psp-timestamp')?.trim();
  final signature = ctx.header('x-psp-signature')?.trim().toLowerCase();
  if (timestamp == null ||
      timestamp.isEmpty ||
      signature == null ||
      !isPspSignatureShape(signature)) {
    throw Failures.invalidSignature;
  }
  final parsed = DateTime.tryParse(timestamp);
  if (parsed == null) throw Failures.invalidSignature;
  final now = ctx.server.clock.now();
  final skew = now.difference(parsed.toUtc());
  if (skew.abs() > webhookTimestampTolerance) throw Failures.invalidSignature;

  final expected = pspWebhookSignature(
    secret: ctx.server.webhookSecret,
    timestamp: timestamp,
    body: rawBody,
  );
  if (!constantTimeEquals(expected, signature)) {
    throw Failures.invalidSignature;
  }
}

WebhookOutcome processWebhookEvent(
  MockServer server, {
  required String provider,
  required String eventId,
  required IntentRecord intent,
  required String type,
}) {
  if (server.webhookSeen(provider, eventId)) {
    return (duplicate: true, changed: false);
  }
  final target = switch (type) {
    'payment.succeeded' => 'succeeded',
    'payment.failed' => 'failed',
    'payment.expired' => 'expired',
    'payment.processing' => 'processing',
    _ => null,
  };
  if (target == null) {
    throw ApiException.validation(
      'unsupported webhook event type',
      fieldErrors: const <String, String>{'type': 'unsupported_event'},
    );
  }
  server.rememberWebhook(provider, eventId);
  final changed = applyPaymentStatus(server, intent, target);
  return (duplicate: false, changed: changed);
}

void applyDueWebhooks(MockServer server) {
  final now = server.clock.now();
  for (final intent in server.intents.values) {
    final due = intent.pendingWebhookAt;
    if (due == null || due.isAfter(now)) continue;
    intent.pendingWebhookAt = null;
    applyPaymentStatus(server, intent, 'succeeded');
    server.audit(
      action: 'payment.webhook',
      objectType: 'intent',
      objectId: intent.id,
      result: 'success',
      actorRole: ActorRole.system,
      details: const <String, Object?>{
        'provider': 'mock_psp',
        'type': 'payment.succeeded',
        'scheduled': true,
      },
    );
  }
}

typedef SimulationResult = ({IntentRecord? intent, OrderRecord? order});

SimulationResult simulate(
  MockServer server,
  String scenario,
  Map<String, Object?> body,
) {
  final order = _simulationOrder(server, body);
  final intent = _simulationIntent(server, body, order);
  final now = server.clock.now();

  switch (scenario) {
    case 'card_success':
      final resolved = _requireIntent(intent);
      applyPaymentStatus(server, resolved, 'succeeded');
      return (intent: resolved, order: server.orders[resolved.orderId]);
    case '3ds_challenge':
      final resolved = _requireIntent(intent);
      applyPaymentStatus(server, resolved, 'requires_action');
      return (intent: resolved, order: server.orders[resolved.orderId]);
    case 'insufficient_funds':
      final resolved = _requireIntent(intent);
      applyPaymentStatus(
        server,
        resolved,
        'failed',
        failureCode: 'insufficient_funds',
      );
      return (intent: resolved, order: server.orders[resolved.orderId]);
    case 'timeout_then_webhook':
      final resolved = _requireIntent(intent);
      applyPaymentStatus(server, resolved, 'processing');
      resolved.pendingWebhookAt = now.add(const Duration(seconds: 2));
      return (intent: resolved, order: server.orders[resolved.orderId]);
    case 'duplicate_webhook':
      final resolved = _requireIntent(intent);
      final eventId = 'sim-duplicate-${resolved.id}';
      processWebhookEvent(
        server,
        provider: resolved.provider,
        eventId: eventId,
        intent: resolved,
        type: 'payment.succeeded',
      );
      processWebhookEvent(
        server,
        provider: resolved.provider,
        eventId: eventId,
        intent: resolved,
        type: 'payment.succeeded',
      );
      return (intent: resolved, order: server.orders[resolved.orderId]);
    case 'refund_full':
      final resolvedOrder = _requireOrder(order);
      refundFull(server, resolvedOrder);
      return (intent: intent, order: resolvedOrder);
    case 'refund_partial':
      final resolvedOrder = _requireOrder(order);
      final amount = body['amountMinor'];
      refundPartially(
        server,
        resolvedOrder,
        amount is int ? amount : resolvedOrder.totalMinor ~/ 2,
      );
      return (
        intent: resolvedOrder.latestIntentId == null
            ? null
            : server.intents[resolvedOrder.latestIntentId],
        order: resolvedOrder,
      );
    case 'zero_amount':
      final resolvedOrder = _requireOrder(order);
      if (resolvedOrder.totalMinor != 0) {
        throw ApiException(422, 'not_zero_amount', 'the order total is not 0');
      }
      if (resolvedOrder.paymentStatus != 'succeeded') {
        resolvedOrder
          ..paymentStatus = 'succeeded'
          ..updatedAt = now;
      }
      return (intent: null, order: resolvedOrder);
    case 'cod_confirm':
      final resolvedOrder = _requireOrder(order);
      final resolvedIntent = _requireIntent(intent);
      applyPaymentStatus(server, resolvedIntent, 'succeeded');
      return (intent: resolvedIntent, order: resolvedOrder);
    default:
      throw ApiException.validation(
        'unknown simulation scenario',
        fieldErrors: const <String, String>{'scenario': 'unknown_scenario'},
      );
  }
}

RefundRecord refundFull(MockServer server, OrderRecord order) {
  final already = order.refunds.fold<int>(
    0,
    (sum, refund) => sum + refund.amountMinor,
  );
  return _createRefund(
    server,
    order,
    order.totalMinor - already,
    'refund.full',
  );
}

RefundRecord refundPartially(
  MockServer server,
  OrderRecord order,
  int amountMinor,
) => _createRefund(server, order, amountMinor, 'refund.partial');

RefundRecord _createRefund(
  MockServer server,
  OrderRecord order,
  int amountMinor,
  String reasonKey,
) {
  if (!order.isPaid) {
    throw ApiException.conflict('not_paid', 'the order is not paid');
  }
  final intent = order.latestIntentId == null
      ? null
      : server.intents[order.latestIntentId];
  if (intent == null) {
    throw ApiException(422, 'nothing_to_refund', 'no captured payment');
  }
  final already = order.refunds.fold<int>(
    0,
    (sum, refund) => sum + refund.amountMinor,
  );
  final remaining = order.totalMinor - already;
  if (amountMinor <= 0 || amountMinor > remaining) {
    throw ApiException.validation(
      'the refund amount must be within 1..$remaining',
      fieldErrors: const <String, String>{'amountMinor': 'out_of_range'},
    );
  }
  final refund = RefundRecord(
    id: server.nextId('rfnd'),
    orderId: order.id,
    intentId: intent.id,
    amountMinor: amountMinor,
    currency: order.currency,
    status: 'succeeded',
    createdAt: server.clock.now(),
    reasonKey: reasonKey,
  );
  server.refunds[refund.id] = refund;
  order.refunds.add(refund);
  final totalRefunded = already + amountMinor;
  applyPaymentStatus(
    server,
    intent,
    totalRefunded >= order.totalMinor ? 'refunded' : 'partially_refunded',
  );
  return refund;
}

void _expireIfNeeded(MockServer server, IntentRecord intent) {
  if (!intent.isPending) return;
  if (!_isExpired(intent, server.clock.now())) return;
  applyPaymentStatus(server, intent, 'expired');
}

bool _isExpired(IntentRecord intent, DateTime now) =>
    !intent.expiresAt.isAfter(now);

IntentRecord _requireIntent(IntentRecord? intent) {
  if (intent == null) {
    throw ApiException.validation(
      'intentId or orderId is required',
      fieldErrors: const <String, String>{'intentId': 'required'},
    );
  }
  return intent;
}

OrderRecord _requireOrder(OrderRecord? order) {
  if (order == null) {
    throw ApiException.validation(
      'orderId or intentId is required',
      fieldErrors: const <String, String>{'orderId': 'required'},
    );
  }
  return order;
}

OrderRecord? _simulationOrder(MockServer server, Map<String, Object?> body) {
  final orderId = body['orderId'];
  if (orderId is String && orderId.isNotEmpty) {
    final order = server.orders[orderId];
    if (order == null) throw ApiException.notFound('unknown order');
    return order;
  }
  final intentId = body['intentId'];
  if (intentId is String && intentId.isNotEmpty) {
    final intent = server.intents[intentId];
    if (intent == null) throw ApiException.notFound('unknown payment intent');
    return server.orders[intent.orderId];
  }
  return null;
}

IntentRecord? _simulationIntent(
  MockServer server,
  Map<String, Object?> body,
  OrderRecord? order,
) {
  final intentId = body['intentId'];
  if (intentId is String && intentId.isNotEmpty) {
    final intent = server.intents[intentId];
    if (intent == null) throw ApiException.notFound('unknown payment intent');
    return intent;
  }
  if (order == null) return null;
  final latest = order.latestIntentId;
  if (latest != null) return server.intents[latest];
  for (final intent in server.intents.values) {
    if (intent.orderId == order.id) return intent;
  }
  return null;
}

String _hostedUrl(MockContext ctx, String intentId) {
  final token = ctx.server.signOpaque(intentId);
  return '${ctx.origin}/v1/mock/psp/hosted/$intentId?token=$token';
}

String _page(String title, String body) =>
    '<!doctype html><html lang="ru"><head><meta charset="utf-8">'
    '<meta name="viewport" content="width=device-width,initial-scale=1">'
    '<title>${escapeHtml(title)}</title>'
    '<style>body{font-family:-apple-system,Segoe UI,Roboto,sans-serif;'
    'background:#fffaf5;color:#2b2118;margin:0;padding:24px}'
    'main{max-width:420px;margin:0 auto;background:#fff;border-radius:16px;'
    'padding:24px;box-shadow:0 8px 32px rgba(43,33,24,.08)}'
    'h1{font-size:20px;margin:0 0 16px}p{margin:8px 0;line-height:1.45}'
    '.amount{font-size:28px;font-weight:600;margin:16px 0}'
    'button{width:100%;padding:14px 16px;border-radius:12px;border:0;'
    'font-size:16px;margin-top:12px;cursor:pointer}'
    '.pay{background:#dd5757;color:#fff}.decline{background:#f3ece4;color:#2b2118}'
    '.muted{color:#6f6258;font-size:13px}</style></head><body><main>'
    '$body</main></body></html>';

String hostedPaymentPage(IntentRecord intent, OrderRecord? order) {
  final status = PaymentStatus.fromWire(intent.status);
  final amount = Money(
    amountMinor: intent.amountMinor,
    currency: intent.currency,
  ).format(locale: 'ru', currencySymbol: intent.currency);
  final action = '/v1/mock/psp/hosted/${intent.id}';
  final token = intent.hostedPageUrl == null
      ? ''
      : Uri.tryParse(intent.hostedPageUrl!)?.queryParameters['token'] ?? '';
  final settleable = status.isPending;
  final body = <String>[
    '<h1>Оплата заказа</h1>',
    '<p class="muted">Заказ ${escapeHtml(order?.number ?? intent.orderId)} · '
        'провайдер ${escapeHtml(intent.provider)} · '
        'метод ${escapeHtml(intent.methodId)}</p>',
    '<div class="amount">${escapeHtml(amount)}</div>',
    if (intent.eripCode != null)
      '<p>Код ЕРИП: <strong>${escapeHtml(intent.eripCode!)}</strong></p>',
    if (intent.qrPayload != null)
      '<p class="muted">QR СБП: ${escapeHtml(intent.qrPayload!)}</p>',
    '<p class="muted">Карточные данные не собираются: страница — песочница '
        'мока. Статус: ${escapeHtml(status.wire)}.</p>',
    if (settleable) ...<String>[
      '<form method="post" action="$action/pay?token=${escapeHtml(token)}">'
          '<button class="pay" type="submit">Оплатить</button></form>',
      '<form method="post" action="$action/decline?token=${escapeHtml(token)}">'
          '<button class="decline" type="submit">Отклонить</button></form>',
    ] else
      '<p><strong>Платёж уже завершён.</strong> Вернитесь в приложение.</p>',
  ].join();
  return _page('PicPac · Оплата', body);
}

String resultPage(
  IntentRecord intent,
  OrderRecord? order, {
  required bool approved,
}) {
  final status = PaymentStatus.fromWire(intent.status);
  final body = <String>[
    '<h1>${approved ? 'Оплата принята' : 'Платёж отклонён'}</h1>',
    '<p>Заказ ${escapeHtml(order?.number ?? intent.orderId)} · '
        'статус ${escapeHtml(status.wire)}</p>',
    '<p class="muted">Вернитесь в приложение: истина о платеже — webhook и '
        'GET /v1/payments/${escapeHtml(intent.id)}.</p>',
  ].join();
  return _page('PicPac · Результат оплаты', body);
}

String receiptPage(ReceiptRecord receipt) {
  final amount = Money(
    amountMinor: receipt.amountMinor,
    currency: receipt.currency,
  ).format(locale: 'ru', currencySymbol: receipt.currency);
  final body = <String>[
    '<h1>Чек</h1>',
    '<p>Заказ ${escapeHtml(receipt.orderId)}</p>',
    '<p>Фискальный номер: ${escapeHtml(receipt.fiscalId)}</p>',
    '<div class="amount">${escapeHtml(amount)}</div>',
    '<p class="muted">Демонстрационный чек мока, не фискальный документ.</p>',
  ].join();
  return _page('PicPac · Чек', body);
}
