import 'package:api_contract/api_contract.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../context.dart';
import '../errors.dart';
import '../mock_server.dart';
import '../seeds.dart';
import '../serialization.dart';

void registerCatalogRoutes(Router router, MockServer server) {
  router.get('/v1/catalog', (Request request) {
    final ctx = contextOf(request);
    final catalog = server.seeds.catalog;
    return ctx.json(catalog.toDto().toJson());
  });

  router.get('/v1/catalog/<productId>', (Request request, String productId) {
    final ctx = contextOf(request);
    final product = server.seeds.catalog.productById(productId);
    if (product == null) {
      throw ApiException.notFound('unknown product "$productId"');
    }
    return ctx.json(product.toDto(server.seeds.catalog.currency).toJson());
  });

  router.get('/v1/catalog/<productId>/formats', (
    Request request,
    String productId,
  ) {
    final ctx = contextOf(request);
    final product = server.seeds.catalog.productById(productId);
    if (product == null) {
      throw ApiException.notFound('unknown product "$productId"');
    }
    return ctx.json(<Object?>[
      for (final format in product.formats) format.toDto(product).toJson(),
    ]);
  });

  router.post('/v1/price', (Request request) async {
    final ctx = contextOf(request);
    final parsed = PriceRequest.fromJson(await ctx.jsonBody());
    final quote = server.pricing.quoteRequest(parsed);
    return ctx.json(quote.toDto().toJson());
  });

  router.get('/v1/delivery/options', (Request request) {
    final ctx = contextOf(request);
    final delivery = server.seeds.delivery;
    return ctx.json(<Object?>[
      for (final option in delivery.options)
        option.toDto(server.seeds.catalog.currency).toJson(),
    ]);
  });

  router.get('/v1/pickup/points', (Request request) {
    final ctx = contextOf(request);
    return ctx.json(<Object?>[
      for (final point in pickupPointsToDto(server.seeds, server.clock.now()))
        point.toJson(),
    ]);
  });
}

SeedPromotion requirePromotion(MockServer server, String code) {
  final promotion = server.seeds.promotions.byCode(code);
  if (promotion == null) {
    throw ApiException(
      422,
      'promo_unknown',
      'the promo code is unknown or expired',
      fieldErrors: const <String, String>{'promoCode': 'promo_unknown'},
    );
  }
  return promotion;
}
