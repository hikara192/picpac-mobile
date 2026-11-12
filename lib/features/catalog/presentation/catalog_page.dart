import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../_shared/application/async_retry.dart';
import '../../../core/presentation/state_views.dart';
import '../application/catalog_controllers.dart';
import 'widgets/product_card.dart';

class CatalogPage extends ConsumerWidget {
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(catalogProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.catalogTitle, style: AppTheme.rootTabTitle),
        actions: <Widget>[
          IconButton(
            key: const Key('catalog-open-projects'),
            tooltip: l10n.projectsTitle,
            onPressed: () => context.push(AppRoutes.projects),
            icon: const Icon(Icons.photo_album_outlined),
          ),
          IconButton(
            tooltip: l10n.catalogCartHint,
            onPressed: () => context.push(AppRoutes.cart),
            icon: const Icon(Icons.shopping_bag_outlined),
          ),
          const SizedBox(width: PicPacSpacing.xs),
        ],
      ),
      body: switch (catalog) {
        AsyncData<CatalogResponse>(:final value) =>
          value.products.isEmpty
              ? EmptyView(
                  title: l10n.catalogEmptyTitle,
                  body: l10n.catalogEmptyBody,
                  icon: Icons.storefront_outlined,
                  action: FilledButton(
                    onPressed: () => ref.invalidate(catalogProvider),
                    child: Text(l10n.actionRetry),
                  ),
                )
              : _CatalogGrid(products: value.products),
        AsyncError<CatalogResponse>(:final error) => FailureView(
          failure: failureOr(error),
          onRetry: () => ref.invalidate(catalogProvider),
          onLogin: () => context.push(AppRoutes.login),
        ),
        _ => const CatalogSkeleton(),
      },
    );
  }
}

class _CatalogGrid extends ConsumerWidget {
  const _CatalogGrid({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oneColumn = MediaQuery.textScalerOf(context).scale(14) > 20;
    return RefreshIndicator(
      color: PicPacColors.accent,
      onRefresh: () async {
        try {
          ref.invalidate(catalogProvider);
          await ref.read(catalogProvider.future);
        } on Object {
        }
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(PicPacSpacing.lg),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: products.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: oneColumn ? 1 : 2,
          mainAxisSpacing: PicPacSpacing.md,
          crossAxisSpacing: PicPacSpacing.md,
          childAspectRatio: oneColumn ? 1.2 : 0.78,
        ),
        itemBuilder: (context, index) {
          final product = products[index];
          return ProductCard(
            product: product,
            onTap: () => context.push('${AppRoutes.catalog}/${product.id}'),
          );
        },
      ),
    );
  }
}
