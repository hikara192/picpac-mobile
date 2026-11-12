import 'package:api_contract/api_contract.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../context.dart';
import '../errors.dart';
import '../mock_server.dart';
import '../seeds.dart';

void registerInspirationRoutes(Router router, MockServer server) {
  router.get('/v1/inspiration', (Request request) {
    final ctx = contextOf(request);
    final customer = ctx.requireUser();
    final query = request.url.queryParameters;
    final tag = _readTag(query['tag']);
    final limit = _readLimit(query['limit']);
    final offset = _readCursor(query['cursor']);

    final sorted = sortedIdeas(server.seeds.inspiration);
    final filtered = tag == null
        ? sorted
        : <SeedInspirationItem>[
            for (final item in sorted)
              if (item.tags.contains(tag)) item,
          ];
    final page = filtered.skip(offset).take(limit).toList();
    final nextOffset = offset + page.length;
    final favorites = server.favoritesOf(customer.id);

    return ctx.json(
      InspirationFeedPage(
        items: <InspirationItem>[
          for (final item in page)
            ideaToDto(item, isFavorite: favorites.contains(item.id)),
        ],
        nextCursor: nextOffset < filtered.length ? '$nextOffset' : null,
      ).toJson(),
    );
  });

  router.get('/v1/inspiration/<inspirationId>', (
    Request request,
    String inspirationId,
  ) {
    final ctx = contextOf(request);
    final customer = ctx.requireUser();
    final item = server.seeds.inspiration.byId(inspirationId);
    if (item == null) {
      throw ApiException.notFound('unknown idea "$inspirationId"');
    }
    final favorites = server.favoritesOf(customer.id);
    return ctx.json(
      InspirationDetail(
        item: ideaToDto(item, isFavorite: favorites.contains(item.id)),
        supports: supportsOf(server, item),
      ).toJson(),
    );
  });

  router.get('/v1/favorites', (Request request) {
    final ctx = contextOf(request);
    final customer = ctx.requireUser();
    final favorites = server.favoritesOf(customer.id);
    return ctx.json(
      InspirationFeedPage(
        items: <InspirationItem>[
          for (final item in sortedIdeas(server.seeds.inspiration))
            if (favorites.contains(item.id)) ideaToDto(item, isFavorite: true),
        ],
      ).toJson(),
    );
  });

  router.post('/v1/favorites/<inspirationId>', (
    Request request,
    String inspirationId,
  ) {
    final ctx = contextOf(request);
    final customer = ctx.requireUser();
    final item = server.seeds.inspiration.byId(inspirationId);
    if (item == null) {
      throw ApiException.notFound('unknown idea "$inspirationId"');
    }
    final favorites = server.favoritesOf(customer.id);
    final added = favorites.add(item.id);
    if (added) {
      ctx.audit(
        action: 'inspiration.favorite_add',
        objectType: 'inspiration',
        objectId: item.id,
      );
    }
    return ctx.json(
      FavoriteState(templateId: item.id, isFavorite: true).toJson(),
    );
  });

  router.delete('/v1/favorites/<inspirationId>', (
    Request request,
    String inspirationId,
  ) {
    final ctx = contextOf(request);
    final customer = ctx.requireUser();
    final favorites = server.favoritesOf(customer.id);
    final removed = favorites.remove(inspirationId);
    if (removed) {
      ctx.audit(
        action: 'inspiration.favorite_remove',
        objectType: 'inspiration',
        objectId: inspirationId,
      );
    }
    return ctx.noContent();
  });
}

List<SeedInspirationItem> sortedIdeas(SeedInspiration inspiration) =>
    <SeedInspirationItem>[...inspiration.items]..sort((a, b) {
      final byPopularity = b.popularity.compareTo(a.popularity);
      return byPopularity != 0 ? byPopularity : a.id.compareTo(b.id);
    });

InspirationItem ideaToDto(
  SeedInspirationItem item, {
  required bool isFavorite,
}) => InspirationItem(
  id: item.id,
  templateId: item.template.id,
  titleKey: item.titleKey,
  tags: item.tags,
  aspect: item.template.aspect,
  slots: item.template.slots,
  productKind: item.productKind,
  popularity: item.popularity,
  isFavorite: isFavorite,
);

List<InspirationSupport> supportsOf(
  MockServer server,
  SeedInspirationItem item,
) {
  final catalog = server.seeds.catalog;
  return <InspirationSupport>[
    for (final support in item.supports)
      if (catalog.productById(support.productId) case final product?)
        if (product.formatById(support.formatId) case final format?)
          InspirationSupport(
            productId: product.id,
            productTitle: product.title,
            formatId: format.id,
            formatTitle: format.title,
            productKind: product.isPrints ? 'print' : 'book',
          ),
  ];
}

String? _readTag(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int _readLimit(String? raw) {
  if (raw == null || raw.isEmpty) return defaultFeedLimit;
  final value = int.tryParse(raw);
  if (value == null || value < 1 || value > maxFeedLimit) {
    throw ApiException.validation(
      'limit must be an integer within 1..$maxFeedLimit',
      fieldErrors: const <String, String>{'limit': 'out_of_range'},
    );
  }
  return value;
}

int _readCursor(String? raw) {
  if (raw == null || raw.isEmpty) return 0;
  final value = int.tryParse(raw);
  if (value == null || value < 0) {
    throw ApiException.validation(
      'cursor is not a value this server issued',
      fieldErrors: const <String, String>{'cursor': 'invalid_cursor'},
    );
  }
  return value;
}

const int defaultFeedLimit = 12;

const int maxFeedLimit = 48;
