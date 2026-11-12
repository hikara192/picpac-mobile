import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../_shared/application/async_retry.dart';
import '../../../core/presentation/format.dart';
import '../../_shared/presentation/product_artwork.dart';
import '../../../core/presentation/state_views.dart';
import '../../../core/presentation/text_tones.dart';
import '../application/projects_controller.dart';

class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final projects = ref.watch(projectsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.projectsTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.actionRetry,
            onPressed: () => ref.invalidate(projectsProvider),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: PicPacSpacing.xs),
        ],
      ),
      body: switch (projects) {
        AsyncData<List<ProjectCardView>>(:final value) =>
          value.isEmpty
              ? EmptyView(
                  title: l10n.projectsEmptyTitle,
                  body: l10n.projectsEmptyBody,
                  icon: Icons.photo_album_outlined,
                  action: FilledButton(
                    onPressed: () => context.go(AppRoutes.catalog),
                    child: Text(l10n.actionGoCatalog),
                  ),
                )
              : RefreshIndicator(
                  color: PicPacColors.accent,
                  onRefresh: () async {
                    try {
                      await ref.read(projectsProvider.notifier).refresh();
                    } on Object {
                    }
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(PicPacSpacing.lg),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: value.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: PicPacSpacing.md),
                    itemBuilder: (context, index) =>
                        _ProjectTile(card: value[index]),
                  ),
                ),
        AsyncError<List<ProjectCardView>>(:final error) => FailureView(
          failure: failureOr(error),
          onRetry: () => ref.invalidate(projectsProvider),
        ),
        _ => const CardListSkeleton(),
      },
    );
  }
}

class _ProjectTile extends ConsumerWidget {
  const _ProjectTile({required this.card});

  final ProjectCardView card;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.projectsDeleteTitle),
        content: Text(l10n.projectsDeleteBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.actionRemove),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(projectsProvider.notifier).delete(card.designId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fmt = Fmt.of(context);
    final title = card.productTitle ?? l10n.cartUnavailableItem;
    final unit = card.perSheet
        ? l10n.cartSheetsUnit(card.sheets)
        : l10n.cartSpreadsUnit(card.sheets);
    return Container(
      decoration: BoxDecoration(
        color: PicPacColors.surface,
        borderRadius: BorderRadius.circular(PicPacRadii.card),
        border: Border.all(color: PicPacColors.border),
      ),
      child: InkWell(
        key: Key('project-${card.designId}'),
        borderRadius: BorderRadius.circular(PicPacRadii.card),
        onTap: () => context.push(AppRoutes.createFor(card.designId)),
        child: Padding(
          padding: const EdgeInsets.all(PicPacSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 64,
                height: 64,
                child: ProductArtwork(
                  seedId: card.productId,
                  category: card.category ?? 'prints',
                ),
              ),
              const SizedBox(width: PicPacSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: PicPacSpacing.xxs),
                    Text(
                      '${l10n.projectsPhotos(card.photoCount)} · $unit',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: FunnelText.secondary,
                      ),
                    ),
                    const SizedBox(height: PicPacSpacing.xxs),
                    Text(
                      l10n.projectsUpdatedAt(fmt.date(card.updatedAt)),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: FunnelText.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.projectsDelete,
                onPressed: () => _confirmDelete(context, ref),
                icon: const Icon(Icons.delete_outline, size: 20),
                color: PicPacColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
