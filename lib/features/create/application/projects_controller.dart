import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../core/orders/preflight_ack.dart';
import '../../../core/session/guest_work.dart';
import '../../_shared/application/async_retry.dart';

final class ProjectCardView {
  const ProjectCardView({
    required this.designId,
    required this.productId,
    required this.updatedAt,
    this.productTitle,
    this.category,
    this.photoCount = 0,
    this.sheets = 0,
    this.perSheet = true,
    this.hasSnapshot = false,
  });

  final String designId;

  final String productId;

  final DateTime updatedAt;

  final String? productTitle;

  final String? category;

  final int photoCount;

  final int sheets;

  final bool perSheet;

  final bool hasSnapshot;
}

final class ProjectsController extends AsyncNotifier<List<ProjectCardView>> {
  @override
  Future<List<ProjectCardView>> build() async {
    final drafts = ref.watch(draftStoreProvider);
    final rows = await drafts.list();
    if (rows.isEmpty) return const <ProjectCardView>[];

    final catalog = (await ref.watch(apiPortProvider).catalog()).valueOrNull;
    final cards = <ProjectCardView>[];
    for (final row in rows) {
      final document = await drafts.load(row.designId);
      if (document == null || document.photoCount == 0) continue;
      final product = _productOf(catalog, row.productId);
      final format = product == null
          ? null
          : _formatOf(product, document.product.formatId);
      cards.add(
        ProjectCardView(
          designId: row.designId,
          productId: row.productId,
          updatedAt: row.updatedAt,
          productTitle: product == null
              ? null
              : format == null
              ? product.title
              : '${product.title} ${format.title}',
          category: product?.category,
          photoCount: document.photoCount,
          sheets: document.spreads.length,
          perSheet: format == null ? true : format.minSpreads <= 0,
          hasSnapshot: true,
        ),
      );
    }
    return cards;
  }

  Future<Failure?> delete(String designId) async {
    final current = state.value ?? const <ProjectCardView>[];
    await ref.read(draftStoreProvider).delete(designId);
    ref.read(preflightAckProvider.notifier).forget(designId);
    ref.read(guestWorkProvider.notifier).forgetDesign(designId);
    state = AsyncData<List<ProjectCardView>>(<ProjectCardView>[
      for (final card in current)
        if (card.designId != designId) card,
    ]);
    final result = await ref.read(apiPortProvider).deleteDesign(designId);
    return result.failureOrNull;
  }

  Future<void> refresh() async {
    ref.invalidate(projectsProvider);
    await ref.read(projectsProvider.future);
  }

  Product? _productOf(CatalogResponse? catalog, String productId) {
    for (final product in catalog?.products ?? const <Product>[]) {
      if (product.id == productId) return product;
    }
    return null;
  }

  ProductFormat? _formatOf(Product product, String formatId) {
    for (final format in product.formats) {
      if (format.id == formatId) return format;
    }
    return null;
  }
}

final projectsProvider =
    AsyncNotifierProvider<ProjectsController, List<ProjectCardView>>(
      ProjectsController.new,
      retry: noProviderRetry,
    );

final localSnapshotProvider = FutureProvider.family<bool, String>((
  ref,
  designId,
) async {
  final snapshot = await ref.watch(draftStoreProvider).load(designId);
  return snapshot != null;
}, retry: noProviderRetry);
