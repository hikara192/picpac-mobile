import 'package:api_contract/api_contract.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../context.dart';
import '../errors.dart';
import '../mock_server.dart';
import '../pricing.dart';
import '../records.dart';
import '../seeds.dart';
import '../security.dart';
import '../serialization.dart';
import 'cart.dart';
import 'designs.dart';

const Map<String, List<String>> orderTransitions = <String, List<String>>{
  'draft': <String>['placed', 'canceled'],
  'placed': <String>['accepted', 'canceled'],
  'accepted': <String>['moderation', 'canceled'],
  'moderation': <String>['production', 'canceled'],
  'production': <String>['ready', 'ready_for_pickup', 'shipped'],
  'ready': <String>['shipped', 'completed'],
  'ready_for_pickup': <String>['completed'],
  'shipped': <String>['completed'],
  'completed': <String>['returned'],
  'canceled': <String>[],
  'returned': <String>[],
};

final class DraftLine {
  const DraftLine({required this.designId, required this.quantity});

  final String designId;

  final int quantity;
}

final class OrderCreation {
  const OrderCreation({required this.order, required this.replay});

  final OrderRecord order;

  final bool replay;
}

void registerOrderRoutes(Router router, MockServer server) {
  router.post('/v1/checkout', (Request request) async {
    final ctx = contextOf(request);
    final customer = ctx.requireCustomer();
    final key = requireIdempotencyKey(ctx);
    final parsed = CheckoutRequest.fromJson(await ctx.jsonBody());

    final idempotent = server.idempotency('checkout', customer.id, key);
    if (idempotent != null) {
      return await _replay(ctx, idempotent);
    }

    final cart = server.carts[customer.id];
    if (cart == null || cart.id != parsed.cartId) {
      throw ApiException.conflict(
        'cart_expired',
        'the cart is unknown, expired or already checked out',
      );
    }
    if (cart.lines.isEmpty) {
      throw ApiException.conflict('cart_empty', 'the cart has no items');
    }

    final created = createOrder(
      ctx: ctx,
      customer: customer,
      lines: <DraftLine>[
        for (final line in cart.lines)
          DraftLine(designId: line.designId, quantity: line.quantity),
      ],
      selection: parsed.delivery,
      contact: parsed.contact,
      promoCode: parsed.promoCode ?? cart.promoCode,
      endpoint: 'checkout',
      idempotencyKey: key,
      bodyHash: MockServer.bodyHash(await ctx.bodyText()),
    );
    server.carts.remove(customer.id);
    ctx.audit(
      action: 'cart.checked_out',
      objectType: 'cart',
      objectId: cart.id,
      details: <String, Object?>{'orderId': created.order.id},
    );
    return ctx.json(created.order.toJson(), status: 201);
  });

  router.post('/v1/orders', (Request request) async {
    final ctx = contextOf(request);
    final customer = ctx.requireCustomer();
    final key = requireIdempotencyKey(ctx);
    final parsed = CreateOrderRequest.fromJson(await ctx.jsonBody());

    final idempotent = server.idempotency('orders', customer.id, key);
    if (idempotent != null) {
      return await _replay(ctx, idempotent);
    }

    final created = createOrder(
      ctx: ctx,
      customer: customer,
      lines: <DraftLine>[
        for (final line in parsed.lines)
          DraftLine(designId: line.designId, quantity: line.quantity),
      ],
      selection: parsed.delivery,
      contact: parsed.contact,
      promoCode: parsed.promoCode,
      endpoint: 'orders',
      idempotencyKey: key,
      bodyHash: MockServer.bodyHash(await ctx.bodyText()),
    );
    return ctx.json(created.order.toJson(), status: 201);
  });

  router.get('/v1/orders', (Request request) {
    final ctx = contextOf(request);
    final session = ctx.requireSession();
    final customer = ctx.requireUser();
    if (customer.isGuest) {
      throw ApiException.forbidden(
        'sign in to a customer account to see the order history',
      );
    }
    final query = request.url.queryParameters;

    final status = query['status'];
    final limit = int.tryParse(query['limit'] ?? '') ?? 20;
    if (limit < 1 || limit > 100) {
      throw ApiException.validation(
        'limit must be within 1..100',
        fieldErrors: const <String, String>{'limit': 'out_of_range'},
      );
    }
    final offset = int.tryParse(query['cursor'] ?? '') ?? 0;
    if (offset < 0) {
      throw ApiException.validation(
        'cursor is invalid',
        fieldErrors: const <String, String>{'cursor': 'invalid'},
      );
    }

    final visible =
        server.orders.values
            .where(
              (order) =>
                  session.role == UserRole.supportAgent ||
                  (!customer.isGuest && order.accessibleBy(customer.id)),
            )
            .where(
              (order) => status == null || order.fulfillmentStatus == status,
            )
            .toList()
          ..sort((a, b) {
            final byDate = b.createdAt.compareTo(a.createdAt);
            return byDate != 0 ? byDate : b.id.compareTo(a.id);
          });

    final page = visible.skip(offset).take(limit).toList();
    final next = offset + page.length < visible.length
        ? (offset + page.length).toString()
        : null;
    return ctx.json(<String, Object?>{
      'orders': <Object?>[for (final order in page) order.toJson()],
      'nextCursor': ?next,
    });
  });

  router.post('/v1/orders/lookup', (Request request) async {
    final ctx = contextOf(request);
    final body = await ctx.jsonBody();
    final number = body['number'];
    final last4 = body['phoneLast4'];
    final fieldErrors = <String, String>{};
    if (number is! String || number.trim().isEmpty) {
      fieldErrors['number'] = 'required';
    } else if (number.trim().length > 32) {
      fieldErrors['number'] = 'invalid';
    }
    if (last4 is! String || !RegExp(r'^[0-9]{4}$').hasMatch(last4)) {
      fieldErrors['phoneLast4'] = 'invalid';
    }
    if (fieldErrors.isNotEmpty) {
      throw ApiException.validation(
        'order number and the last four phone digits are required',
        fieldErrors: fieldErrors,
      );
    }

    final normalizedNumber = (number as String).trim().toUpperCase();
    final bucket = 'lookup|${ctx.clientIp}|$normalizedNumber';
    final lock = server.lockRemaining(bucket);
    if (lock != null) throw ApiException.rateLimited(lock);

    for (final order in server.orders.values) {
      if (order.number.toUpperCase() == normalizedNumber &&
          order.contactPhoneLast4 == last4) {
        server.clearFailures(bucket);
        ctx.audit(
          action: 'order.lookup',
          objectType: 'order',
          objectId: order.id,
          details: const <String, Object?>{'scope': 'card'},
        );
        return ctx.json(order.toPublicCardJson());
      }
    }
    server.recordFailure(bucket, maxAttempts: lookupMaxFailures);
    ctx.audit(
      action: 'order.lookup',
      objectType: 'order',
      objectId: 'unknown',
      result: 'denied',
      details: const <String, Object?>{'reason': 'no_match'},
    );
    throw ApiException.notFound('order not found');
  });

  router.post('/v1/orders/<orderId>/claim', (
    Request request,
    String orderId,
  ) async {
    final ctx = contextOf(request);
    final customer = ctx.requireCustomer();
    final key = requireIdempotencyKey(ctx);
    final body = await ctx.jsonBody();
    final order = server.orders[orderId];
    if (order == null) throw ApiException.notFound('unknown order');

    final bucket = 'claim|${ctx.clientIp}|${order.number}';
    final lock = server.lockRemaining(bucket);
    if (lock != null) throw ApiException.rateLimited(lock);

    final idempotent = server.idempotency('claim', customer.id, key);
    if (idempotent != null) {
      return await _replay(ctx, idempotent);
    }

    if (order.ownerId == customer.id) {
      return ctx.json(order.toJson());
    }

    final owner = server.customerById(order.ownerId);
    final ownedByGuest = owner == null || owner.isGuest || owner.deleted;
    if (!ownedByGuest) {
      server.recordFailure(bucket, maxAttempts: claimMaxFailures);
      ctx.audit(
        action: 'order.claim',
        objectType: 'order',
        objectId: order.id,
        result: 'denied',
        details: const <String, Object?>{'reason': 'already_claimed'},
      );
      throw ApiException.conflict(
        'order_already_claimed',
        'the order already belongs to a customer account',
      );
    }

    final last4 = body['phoneLast4'];
    if (last4 is! String || last4 != order.contactPhoneLast4) {
      server.recordFailure(bucket, maxAttempts: claimMaxFailures);
      ctx.audit(
        action: 'order.claim',
        objectType: 'order',
        objectId: order.id,
        result: 'denied',
        details: const <String, Object?>{'reason': 'phone_mismatch'},
      );
      throw ApiException.forbidden(
        'the order cannot be claimed: the phone digits do not match',
      );
    }

    server.clearFailures(bucket);
    order.accessIds.add(order.ownerId);
    order.ownerId = customer.id;
    ctx.audit(
      action: 'order.claim',
      objectType: 'order',
      objectId: order.id,
      details: const <String, Object?>{'previousOwner': 'guest'},
    );
    server.rememberIdempotency(
      IdempotencyRecord(
        key: key,
        endpoint: 'claim',
        bodyHash: MockServer.bodyHash(await ctx.bodyText()),
        customerId: customer.id,
        resultType: 'order',
        resultId: order.id,
      ),
    );
    return ctx.json(order.toJson());
  });

  router.get('/v1/orders/<orderId>', (Request request, String orderId) {
    final ctx = contextOf(request);
    final session = ctx.requireSession();
    final customer = ctx.requireUser();
    final order = server.orders[orderId];
    if (order == null) throw ApiException.notFound('unknown order');
    final isSupport = session.role == UserRole.supportAgent;
    if (!isSupport && !order.accessibleBy(customer.id)) {
      ctx.audit(
        action: 'order.access',
        objectType: 'order',
        objectId: orderId,
        result: 'denied',
        details: const <String, Object?>{'reason': 'foreign_order'},
      );
      throw ApiException.forbidden('the order belongs to another customer');
    }
    return ctx.json(order.toJson());
  });

  if (server.mockControlsEnabled) {
    router.post('/v1/mock/orders/<orderId>/advance', (
      Request request,
      String orderId,
    ) async {
      final ctx = contextOf(request);
      final session = ctx.requireSession();
      final customer = ctx.requireUser();
      final order = server.orders[orderId];
      if (order == null) throw ApiException.notFound('unknown order');
      final isSupport = session.role == UserRole.supportAgent;
      if (!isSupport && !order.accessibleBy(customer.id)) {
        ctx.audit(
          action: 'order.advance',
          objectType: 'order',
          objectId: orderId,
          result: 'denied',
          details: const <String, Object?>{'reason': 'foreign_order'},
        );
        throw ApiException.forbidden('the order belongs to another customer');
      }

      final body = await ctx.jsonBody();
      final requested = body['to'];
      final force = body['force'] == true;
      if (!isSupport &&
          !MockEnv.customerAdvance &&
          (requested != 'canceled' || force)) {
        throw Failures.advanceNeedsSupport;
      }
      final previous = order.fulfillmentStatus;
      final target = requested is String && requested.trim().isNotEmpty
          ? requested.trim()
          : _nextStatus(order);
      if (target == null) {
        throw ApiException.conflict(
          'invalid_transition',
          'the order is already in a terminal state',
          extra: <String, Object?>{'from': previous},
        );
      }

      final known = OrderStatus.fromWire(target) != OrderStatus.unknown;
      final allowed = orderTransitions[previous] ?? const <String>[];
      if (known && !allowed.contains(target)) {
        throw ApiException.conflict(
          'invalid_transition',
          'the order cannot move from $previous to $target',
          extra: <String, Object?>{
            'from': previous,
            'to': target,
            'allowed': allowed,
          },
        );
      }
      if (!known && !force) {
        throw ApiException.validation(
          'an unknown status can only be injected with force: true',
          fieldErrors: const <String, String>{'to': 'unknown_status'},
        );
      }

      applyFulfillment(order, target, server.clock.now());
      ctx.audit(
        action: 'order.advance',
        objectType: 'order',
        objectId: order.id,
        details: <String, Object?>{
          'from': previous,
          'to': target,
          'paymentStatus': order.paymentStatus,
        },
      );
      return ctx.json(order.toJson());
    });
  }
}

void applyFulfillment(OrderRecord order, String target, DateTime at) {
  order
    ..fulfillmentStatus = target
    ..updatedAt = at;
  if (target == 'shipped' && order.trackingNumber == null) {
    final digits = order.number.replaceAll(RegExp(r'[^0-9]'), '');
    final seed = int.tryParse(digits) ?? 1001;
    order.trackingNumber =
        'BY${(10000000 + (seed * 7919) % 90000000).toString()}';
  }
  order.history.add(
    StatusEventRecord(
      status: target,
      at: at,
      commentKey: 'order.comment.$target',
    ),
  );
}

String? _nextStatus(OrderRecord order) {
  switch (order.fulfillmentStatus) {
    case 'draft':
      return 'placed';
    case 'placed':
      return 'accepted';
    case 'accepted':
      return 'moderation';
    case 'moderation':
      return 'production';
    case 'production':
      return order.deliveryKind == DeliveryKind.pickup
          ? 'ready_for_pickup'
          : 'ready';
    case 'ready':
      return 'shipped';
    case 'ready_for_pickup':
      return 'completed';
    case 'shipped':
      return 'completed';
    default:
      return null;
  }
}

OrderCreation createOrder({
  required MockContext ctx,
  required CustomerRecord customer,
  required List<DraftLine> lines,
  required DeliverySelection selection,
  required ContactInfo contact,
  required String? promoCode,
  required String endpoint,
  required String idempotencyKey,
  required String bodyHash,
}) {
  final server = ctx.server;
  if (lines.isEmpty) {
    throw ApiException.validation(
      'at least one design is required',
      fieldErrors: const <String, String>{'lines': 'empty'},
    );
  }

  final contactName = contact.name.trim();
  if (contactName.isEmpty || contactName.length > 100) {
    throw ApiException.validation(
      'contact name is required',
      fieldErrors: const <String, String>{'contact.name': 'required'},
    );
  }
  final phoneDigits = digitsOnly(contact.phone);
  if (phoneDigits.length < 7 || phoneDigits.length > 15) {
    throw ApiException.validation(
      'contact phone must contain 7..15 digits',
      fieldErrors: const <String, String>{'contact.phone': 'invalid_phone'},
    );
  }
  final email = contact.email?.trim();
  if (email != null && email.isNotEmpty && !email.contains('@')) {
    throw ApiException.validation(
      'contact email is invalid',
      fieldErrors: const <String, String>{'contact.email': 'invalid_email'},
    );
  }

  final deliveryOption = server.pricing.resolveDeliverySelection(selection);
  if (selection.kind == DeliveryKind.pickup) {
    _requirePickupSlot(server, selection);
  }

  final priced =
      <
        ({DraftLine line, SeedProduct product, SeedFormat format, Quote quote})
      >[];
  for (final line in lines) {
    if (line.quantity < 1 || line.quantity > maxCartQuantity) {
      throw ApiException.validation(
        'quantity must be within 1..$maxCartQuantity',
        fieldErrors: <String, String>{
          'lines.${line.designId}': 'invalid_quantity',
        },
      );
    }
    final design = server.designs[line.designId];
    if (design == null || design.ownerId != customer.id) {
      throw ApiException.validation(
        'the design is unknown or belongs to another customer',
        fieldErrors: <String, String>{
          'lines.${line.designId}': 'unknown_design',
        },
      );
    }
    final product = server.seeds.catalog.productById(
      design.document.product.id,
    );
    final format = product?.formatById(design.document.product.formatId);
    if (product == null || format == null) {
      throw ApiException.validation(
        'the design references a format that is not in the catalogue',
        fieldErrors: <String, String>{
          'lines.${line.designId}': 'unknown_format',
        },
      );
    }
    if (design.document.spreads.isEmpty ||
        design.document.filledSlotCount == 0) {
      throw ApiException.validation(
        'an empty design cannot be ordered',
        fieldErrors: <String, String>{'lines.${line.designId}': 'empty_design'},
      );
    }
    final report = preflightReport(server, design.document);
    if (report.hasBlockingIssues) {
      throw ApiException(
        422,
        'preflight_blocked',
        'the design has blocking preflight issues; fix or acknowledge them',
        fieldErrors: <String, String>{
          'lines.${line.designId}': 'preflight_blocked',
        },
        extra: <String, Object?>{
          'preflight': <String, Object?>{
            'designId': design.id,
            'issues': <Object?>[
              for (final issue in report.blocking) issue.toJson(),
            ],
          },
        },
      );
    }
    final quote = server.pricing.quote(
      product: product,
      format: format,
      options: design.document.product.options,
      units: pricingUnitsOf(product, design.document, line.quantity),
      copies: pricingCopiesOf(product, line.quantity),
    );
    priced.add((line: line, product: product, format: format, quote: quote));
  }

  final itemsSubtotal = priced.fold<int>(
    0,
    (sum, item) => sum + item.quote.totalMinor,
  );
  final deliveryMinor = deliveryOption.priceFor(itemsSubtotal);

  SeedPromotion? promotion;
  if (promoCode != null && promoCode.trim().isNotEmpty) {
    promotion = server.seeds.promotions.byCode(promoCode);
    if (promotion == null) {
      throw ApiException(
        422,
        'promo_unknown',
        'the promo code is unknown or expired',
        fieldErrors: const <String, String>{'promoCode': 'promo_unknown'},
      );
    }
  }
  final discount = promotion == null
      ? 0
      : promotion.percent >= 100
      ? -(itemsSubtotal + deliveryMinor)
      : -((itemsSubtotal * promotion.percent) ~/ 100);
  final total = (itemsSubtotal + discount + deliveryMinor).clamp(0, 1 << 62);

  final now = server.clock.now();
  final productionDays = priced
      .map((item) => item.product.productionDays)
      .reduce((a, b) => a > b ? a : b);
  final etaDate = now.add(
    Duration(days: productionDays + deliveryOption.etaDays),
  );
  final number = server.nextOrderNumber();
  final order = OrderRecord(
    id: server.nextId('ord'),
    number: number,
    ownerId: customer.id,
    createdAt: now,
    updatedAt: now,
    items: <OrderLineRecord>[
      for (final item in priced)
        OrderLineRecord(
          designId: item.line.designId,
          productId: item.product.id,
          productTitle: '${item.product.title} ${item.format.title}',
          formatId: item.format.id,
          quantity: item.line.quantity,
          unitPriceMinor: item.quote.unitPriceMinor,
          totalMinor: item.quote.totalMinor,
        ),
    ],
    itemsSubtotalMinor: itemsSubtotal,
    discountMinor: discount,
    deliveryMinor: deliveryMinor,
    totalMinor: total,
    promoCode: promotion?.code,
    paymentStatus: total == 0 ? 'succeeded' : 'created',
    fulfillmentStatus: 'placed',
    deliveryKind: selection.kind,
    deliveryOptionId: deliveryOption.id,
    deliveryPointId: selection.pointId,
    deliveryAddress: selection.address,
    deliverySlot: selection.slot,
    eta: DateTime.utc(etaDate.year, etaDate.month, etaDate.day),
    pickupCode: selection.kind == DeliveryKind.pickup
        ? number.substring(number.length - 4)
        : null,
    contactName: contactName,
    contactPhone: phoneDigits,
    contactPhoneLast4: phoneDigits.substring(phoneDigits.length - 4),
    currency: server.seeds.catalog.currency,
    history: <StatusEventRecord>[
      StatusEventRecord(
        status: 'placed',
        at: now,
        commentKey: 'order.comment.placed',
      ),
    ],
  );
  server.orders[order.id] = order;
  server.rememberIdempotency(
    IdempotencyRecord(
      key: idempotencyKey,
      endpoint: endpoint,
      bodyHash: bodyHash,
      customerId: customer.id,
      resultType: 'order',
      resultId: order.id,
    ),
  );
  ctx.audit(
    action: 'order.create',
    objectType: 'order',
    objectId: order.id,
    details: <String, Object?>{
      'number': order.number,
      'items': order.items.length,
      'totalMinor': total,
      'currency': order.currency,
      'paymentStatus': order.paymentStatus,
      'delivery': deliveryOption.id,
      'promoCode': order.promoCode,
      'contactPhone': maskPhoneLast4(order.contactPhoneLast4),
    },
  );
  return OrderCreation(order: order, replay: false);
}

void _requirePickupSlot(MockServer server, DeliverySelection selection) {
  final slot = selection.slot;
  if (slot == null) {
    throw ApiException.validation(
      'a pickup slot is required',
      fieldErrors: const <String, String>{'delivery.slot': 'required'},
    );
  }
  final points = pickupPointsToDto(server.seeds, server.clock.now());
  for (final point in points) {
    if (point.id != selection.pointId) continue;
    for (final candidate in point.slots) {
      if (candidate.start.isAtSameMomentAs(slot) && candidate.available) {
        return;
      }
    }
  }
  throw ApiException.validation(
    'the pickup slot is not available',
    fieldErrors: const <String, String>{'delivery.slot': 'unavailable'},
  );
}

Future<Response> _replay(MockContext ctx, IdempotencyRecord record) async {
  final bodyHash = MockServer.bodyHash(await ctx.bodyText());
  if (bodyHash != record.bodyHash) {
    throw ApiException(
      422,
      ApiErrorCode.idempotencyConflict,
      'the same Idempotency-Key was used with a different request body',
    );
  }
  final order = ctx.server.orders[record.resultId];
  if (order == null) throw ApiException.notFound('the stored order is gone');
  return ctx.json(
    order.toJson(),
    headers: const <String, String>{'idempotent-replay': 'true'},
  );
}

String requireIdempotencyKey(MockContext ctx) {
  final key = ctx.header('idempotency-key')?.trim();
  if (key == null || key.isEmpty) throw Failures.idempotencyKeyRequired;
  if (key.length > 128) {
    throw ApiException.validation(
      'Idempotency-Key must be at most 128 characters',
      fieldErrors: const <String, String>{'Idempotency-Key': 'too_long'},
    );
  }
  return key;
}
