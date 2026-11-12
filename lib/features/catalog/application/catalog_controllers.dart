import 'package:api_contract/api_contract.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../core/analytics.dart';
import '../../../core/session/session_service.dart';
import '../../../core/storage/draft_store.dart';
import '../../_shared/application/async_retry.dart';
import '../../_shared/application/design_session.dart';

final class FormatOfferView {
  const FormatOfferView({required this.format, this.quote});

  final ProductFormat format;

  final PriceQuote? quote;
}

final class ProductOfferView {
  const ProductOfferView({required this.product, required this.formats});

  final Product product;

  final List<FormatOfferView> formats;

  FormatOfferView? offerOf(String formatId) {
    for (final offer in formats) {
      if (offer.format.id == formatId) return offer;
    }
    return null;
  }
}

final class CatalogController extends AsyncNotifier<CatalogResponse> {
  @override
  Future<CatalogResponse> build() async {
    final session = ref.watch(sessionServiceProvider);
    final analytics = ref.watch(analyticsProvider);
    final result = await session.ensurePublic(
      () => ref.watch(apiPortProvider).catalog(),
    );
    return result.fold(
      ok: (catalog) {
        analytics.track(AnalyticsEvent.catalogViewed, <String, Object?>{
          'products': catalog.products.length,
        });
        return catalog;
      },
      err: (failure) => throw failure,
    );
  }
}

final catalogProvider =
    AsyncNotifierProvider<CatalogController, CatalogResponse>(
      CatalogController.new,
      retry: noProviderRetry,
    );

final class ProductController extends AsyncNotifier<ProductOfferView> {
  ProductController(this.productId);

  final String productId;

  @override
  Future<ProductOfferView> build() async {
    final api = ref.watch(apiPortProvider);
    final session = ref.watch(sessionServiceProvider);
    final analytics = ref.watch(analyticsProvider);
    final result = await session.ensurePublic(() => api.product(productId));
    final product = result.fold(
      ok: (value) => value,
      err: (failure) => throw failure,
    );
    analytics.track(AnalyticsEvent.productOpened, <String, Object?>{
      'productId': product.id,
      'formats': product.formats.length,
      'options': product.formats.fold<int>(
        0,
        (sum, format) => sum + format.options.length,
      ),
    });

    final formats = await Future.wait<FormatOfferView>(
      product.formats.map((format) async {
        final quote = await api.price(
          PriceRequest(
            productId: product.id,
            formatId: format.id,
            spreadsCount: previewUnits(format),
          ),
        );
        return FormatOfferView(format: format, quote: quote.valueOrNull);
      }),
    );
    return ProductOfferView(product: product, formats: formats);
  }

  static int previewUnits(ProductFormat format) {
    if (format.minSpreads > 0) return format.minSpreads;
    if (format.spreadStep > 1) return format.spreadStep;
    return 1;
  }

  Future<PriceQuote?> quote({
    required ProductFormat format,
    required Map<String, String> options,
  }) async {
    final view = state.value;
    if (view == null) return null;
    final result = await ref
        .read(apiPortProvider)
        .price(
          PriceRequest(
            productId: view.product.id,
            formatId: format.id,
            options: options,
            spreadsCount: previewUnits(format),
          ),
        );
    return result.valueOrNull;
  }
}

final productProvider =
    AsyncNotifierProvider.family<ProductController, ProductOfferView, String>(
      ProductController.new,
      retry: noProviderRetry,
    );

final class ProductQuoteKey {
  const ProductQuoteKey({
    required this.productId,
    required this.formatId,
    required this.spreadsCount,
    this.options = const <String, String>{},
  });

  final String productId;
  final String formatId;
  final int spreadsCount;
  final Map<String, String> options;

  @override
  bool operator ==(Object other) =>
      other is ProductQuoteKey &&
      other.productId == productId &&
      other.formatId == formatId &&
      other.spreadsCount == spreadsCount &&
      const MapEquality<String, String>().equals(other.options, options);

  @override
  int get hashCode => Object.hash(
    productId,
    formatId,
    spreadsCount,
    const MapEquality<String, String>().hash(options),
  );
}

final productQuoteProvider =
    FutureProvider.family<PriceQuote?, ProductQuoteKey>(
      (ref, key) async {
        final result = await ref
            .watch(apiPortProvider)
            .price(
              PriceRequest(
                productId: key.productId,
                formatId: key.formatId,
                options: key.options,
                spreadsCount: key.spreadsCount,
              ),
            );
        return result.valueOrNull;
      },
      retry: noProviderRetry,
      isAutoDispose: true,
    );

Map<String, String> defaultOptionsOf(ProductFormat format) => <String, String>{
  for (final option in format.options)
    if (option.values.isNotEmpty)
      option.id:
          (option.values.firstWhereOrNull((value) => value.isDefault) ??
                  option.values.first)
              .id,
};

final class DraftStarter {
  DraftStarter({required this._drafts, required this._analytics});

  final DraftStore _drafts;
  final Analytics _analytics;

  Future<Result<DesignDto>> start({
    required Product product,
    required ProductFormat format,
    Map<String, String> options = const <String, String>{},
  }) async {
    final document = DesignDocument.start(
      product: DocumentProduct(
        id: product.id,
        formatId: format.id,
        options: options,
      ),
    );
    final designId =
        '$kLocalDesignPrefix${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().toUtc();
    try {
      await _drafts.saveNow(
        document,
        designId: designId,
        productId: product.id,
      );
    } on Object {
      return Err<DesignDto>(
        const ApiFailure(
          code: 'storage_unavailable',
          message: 'the local draft cannot be written',
        ),
      );
    }
    _analytics.track(AnalyticsEvent.projectCreated, <String, Object?>{
      'productId': product.id,
      'formatId': format.id,
      'options': options.length,
      'local': true,
    });
    return Ok<DesignDto>(
      DesignDto(id: designId, revision: 0, document: document, updatedAt: now),
    );
  }
}

final Provider<DraftStarter> draftStarterProvider = Provider<DraftStarter>(
  (ref) => DraftStarter(
    drafts: ref.watch(draftStoreProvider),
    analytics: ref.watch(analyticsProvider),
  ),
);
