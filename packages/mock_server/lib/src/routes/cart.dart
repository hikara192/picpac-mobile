import 'package:api_contract/api_contract.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../context.dart';
import '../errors.dart';
import '../mock_server.dart';
import '../records.dart';
import '../serialization.dart';
import 'catalog.dart';

const int maxCartQuantity = 100;

void registerCartRoutes(Router router, MockServer server) {
  router.get('/v1/cart', (Request request) {
    final ctx = contextOf(request);
    final customer = ctx.requireUser();
    final cart = server.cartFor(customer.id);
    return ctx.json(cartToDto(server, cart).toJson());
  });

  router.post('/v1/cart/items', (Request request) async {
    final ctx = contextOf(request);
    final customer = ctx.requireUser();
    final parsed = AddCartItemRequest.fromJson(await ctx.jsonBody());
    _validateQuantity(parsed.quantity);

    final design = server.designs[parsed.designId];
    if (design == null || design.ownerId != customer.id) {
      throw ApiException.validation(
        'the design is unknown or belongs to another customer',
        fieldErrors: const <String, String>{'designId': 'unknown_design'},
      );
    }
    _requirePricedDesign(server, design, parsed.quantity);

    final cart = server.cartFor(customer.id);
    final existing = cart.lines
        .where((line) => line.designId == parsed.designId)
        .firstOrNull;
    if (existing != null) {
      final next = existing.quantity + parsed.quantity;
      _validateQuantity(next);
      existing.quantity = next;
    } else {
      cart.lines.add(
        CartLineRecord(
          id: server.nextId('cli'),
          designId: parsed.designId,
          quantity: parsed.quantity,
        ),
      );
    }
    ctx.audit(
      action: 'cart.item_add',
      objectType: 'cart',
      objectId: cart.id,
      details: <String, Object?>{
        'designId': parsed.designId,
        'quantity': parsed.quantity,
      },
    );
    return ctx.json(cartToDto(server, cart).toJson());
  });

  router.patch('/v1/cart/items/<itemId>', (
    Request request,
    String itemId,
  ) async {
    final ctx = contextOf(request);
    final customer = ctx.requireUser();
    final body = await ctx.jsonBody();
    final bodyItemId = body['itemId'];
    if (bodyItemId != null && bodyItemId != itemId) {
      throw ApiException.validation(
        'itemId does not match the path',
        fieldErrors: const <String, String>{'itemId': 'path_mismatch'},
      );
    }
    final parsed = UpdateCartItemRequest.fromJson(<String, Object?>{
      ...body,
      'itemId': itemId,
    }, r'$.body');
    final cart = server.cartFor(customer.id);
    final line = cart.lines
        .where((candidate) => candidate.id == itemId)
        .firstOrNull;
    if (line == null) throw ApiException.notFound('unknown cart item');

    if (parsed.quantity != null) {
      _validateQuantity(parsed.quantity!);
      line.quantity = parsed.quantity!;
    }
    if (body.containsKey('promoCode')) {
      final raw = body['promoCode'];
      if (raw == null || (raw is String && raw.trim().isEmpty)) {
        cart.promoCode = null;
      } else if (raw is String) {
        cart.promoCode = requirePromotion(server, raw).code;
      } else {
        throw ApiException.validation(
          'promoCode must be a string',
          fieldErrors: const <String, String>{'promoCode': 'invalid_type'},
        );
      }
    }
    ctx.audit(
      action: 'cart.item_update',
      objectType: 'cart',
      objectId: cart.id,
      details: <String, Object?>{
        'itemId': itemId,
        'quantity': line.quantity,
        'promoCode': cart.promoCode,
      },
    );
    return ctx.json(cartToDto(server, cart).toJson());
  });

  router.delete('/v1/cart/items/<itemId>', (Request request, String itemId) {
    final ctx = contextOf(request);
    final customer = ctx.requireUser();
    final cart = server.cartFor(customer.id);
    final before = cart.lines.length;
    cart.lines.removeWhere((line) => line.id == itemId);
    if (cart.lines.length == before) {
      throw ApiException.notFound('unknown cart item');
    }
    ctx.audit(
      action: 'cart.item_remove',
      objectType: 'cart',
      objectId: cart.id,
      details: <String, Object?>{'itemId': itemId},
    );
    return ctx.json(cartToDto(server, cart).toJson());
  });
}

void _validateQuantity(int quantity) {
  if (quantity < 1 || quantity > maxCartQuantity) {
    throw ApiException.validation(
      'quantity must be within 1..$maxCartQuantity',
      fieldErrors: <String, String>{
        'quantity': quantity < 1 ? 'below_minimum' : 'too_many',
      },
    );
  }
}

void _requirePricedDesign(
  MockServer server,
  DesignRecord design,
  int quantity,
) {
  final product = server.seeds.catalog.productById(design.document.product.id);
  final format = product?.formatById(design.document.product.formatId);
  if (product == null || format == null) {
    throw ApiException.validation(
      'the design references a format that is not in the catalogue',
      fieldErrors: const <String, String>{'designId': 'unknown_format'},
    );
  }
  server.pricing.quote(
    product: product,
    format: format,
    options: design.document.product.options,
    units: pricingUnitsOf(product, design.document, quantity),
    copies: pricingCopiesOf(product, quantity),
  );
}

extension on Iterable<CartLineRecord> {
  CartLineRecord? get firstOrNull {
    for (final value in this) {
      return value;
    }
    return null;
  }
}
