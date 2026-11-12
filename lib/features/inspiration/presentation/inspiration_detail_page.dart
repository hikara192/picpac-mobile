import 'package:api_contract/api_contract.dart' hide TextAlign;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../_shared/application/async_retry.dart';
import '../../../core/presentation/a11y.dart';
import '../../../core/presentation/state_views.dart';
import '../application/inspiration_controllers.dart';
import '../application/template_applier.dart';
import 'inspiration_labels.dart';
import 'widgets/template_preview.dart';

class InspirationDetailPage extends ConsumerStatefulWidget {
  const InspirationDetailPage({required this.inspirationId, super.key});

  final String inspirationId;

  @override
  ConsumerState<InspirationDetailPage> createState() =>
      _InspirationDetailPageState();
}

class _InspirationDetailPageState extends ConsumerState<InspirationDetailPage> {
  int? _selectedSlot;
  bool _applying = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = inspirationDetailProvider(widget.inspirationId);
    final detail = ref.watch(provider);
    final favorites = ref.watch(favoritesProvider);
    final item = detail.value?.item;
    final isFavorite = item == null
        ? false
        : favorites[item.id] ?? item.isFavorite;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.inspirationDetailTitle),
        actions: <Widget>[
          if (item != null)
            IconButton(
              key: const Key('inspiration-detail-favorite'),
              tooltip: isFavorite
                  ? l10n.inspirationRemoveTitle(ideaTitle(l10n, item.titleKey))
                  : l10n.inspirationSaveTitle(ideaTitle(l10n, item.titleKey)),
              isSelected: isFavorite,
              selectedIcon: const Icon(Icons.favorite),
              onPressed: () => _toggleFavorite(item),
              icon: const Icon(Icons.favorite_border),
            ),
          const SizedBox(width: PicPacSpacing.xs),
        ],
      ),
      body: switch (detail) {
        AsyncData<InspirationDetail>(:final value) => _body(l10n, value),
        AsyncError<InspirationDetail>(:final error) => FailureView(
          failure: failureOr(error),
          onRetry: () => ref.invalidate(provider),
          onLogin: () => context.push(AppRoutes.login),
        ),
        _ => const _DetailSkeleton(),
      },
    );
  }

  Widget _body(AppLocalizations l10n, InspirationDetail detail) {
    final theme = Theme.of(context);
    final item = detail.item;
    final title = ideaTitle(l10n, item.titleKey);
    final favorites = ref.watch(favoritesProvider);
    final isFavorite = favorites[item.id] ?? item.isFavorite;
    final supports = detail.supportLabels;
    return ListView(
      padding: const EdgeInsets.all(PicPacSpacing.lg),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(PicPacSpacing.md),
              decoration: BoxDecoration(
                color: PicPacColors.surface,
                borderRadius: BorderRadius.circular(PicPacRadii.card),
                border: Border.all(color: PicPacColors.border),
              ),
              child: AspectRatio(
                aspectRatio: item.aspect.isFinite && item.aspect > 0
                    ? item.aspect
                    : 1,
                child: LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final index = TemplatePreview.slotAt(
                        details.localPosition,
                        constraints.biggest,
                        item.slots,
                      );
                      if (index == null || index == _selectedSlot) return;
                      setState(() => _selectedSlot = index);
                    },
                    child: TemplatePreview(
                      slots: item.slots,
                      aspect: item.aspect,
                      selectedSlot: _selectedSlot ?? 0,
                      background: PicPacColors.surfaceMuted,
                      semanticLabel: ideaPreviewLabel(
                        l10n,
                        title,
                        item.slotCount,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: PicPacSpacing.xl),
        Text(title, style: theme.textTheme.headlineSmall),
        if (item.tags.isNotEmpty) ...<Widget>[
          const SizedBox(height: PicPacSpacing.sm),
          Wrap(
            spacing: PicPacSpacing.sm,
            runSpacing: PicPacSpacing.xs,
            children: <Widget>[
              for (final tag in item.tags)
                Chip(
                  label: Text(ideaTag(l10n, tag)),
                  backgroundColor: PicPacColors.fillStone,
                  side: BorderSide.none,
                  labelStyle: theme.textTheme.labelMedium?.copyWith(
                    color: PicPacColors.inkStrong,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: PicPacSpacing.lg),
        Text(
          detail.isSupported
              ? l10n.inspirationSupportsLabel(supports.join(' / '))
              : l10n.inspirationNoSupports,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: PicPacColors.secondaryText,
          ),
        ),
        const SizedBox(height: PicPacSpacing.xl),
        MinTapTarget(
          child: FilledButton.icon(
            key: const Key('inspiration-apply'),
            onPressed: detail.isSupported && !_applying
                ? () => _apply(detail)
                : null,
            icon: _applying
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            label: Text(
              _applying ? l10n.inspirationApplying : l10n.inspirationApply,
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(kMinTouchTarget),
            ),
          ),
        ),
        const SizedBox(height: PicPacSpacing.sm),
        MinTapTarget(
          child: OutlinedButton.icon(
            onPressed: () => _toggleFavorite(item),
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? PicPacColors.accent : null,
            ),
            label: Text(
              isFavorite
                  ? l10n.inspirationRemoveFromFavorites
                  : l10n.inspirationSaveToFavorites,
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(kMinTouchTarget),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleFavorite(InspirationItem item) async {
    final l10n = AppLocalizations.of(context);
    final failure = await ref.read(favoritesProvider.notifier).toggle(item);
    if (failure == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.inspirationFavoriteFailed)));
  }

  Future<void> _apply(InspirationDetail detail) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _applying = true);
    final outcome = await ref.read(templateApplierProvider).apply(detail);
    if (!mounted) return;
    setState(() => _applying = false);
    final designId = outcome.designId;
    if (designId != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.inspirationApplyReady)));
      context.go(AppRoutes.editorFor(designId));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.inspirationApplyProblemTitle),
        content: Text(_problemText(l10n, outcome)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.actionClose),
          ),
        ],
      ),
    );
  }

  String _problemText(AppLocalizations l10n, TemplateApplyOutcome outcome) =>
      switch (outcome.problem) {
        TemplateApplyProblem.notEnoughPhotos =>
          l10n.inspirationApplyNotEnoughPhotos(
            outcome.slotCount,
            outcome.photoCount,
          ),
        TemplateApplyProblem.notSupported => l10n.inspirationApplyNotSupported,
        TemplateApplyProblem.formatUnavailable => l10n.inspirationApplyNoFormat,
        TemplateApplyProblem.commandRejected =>
          l10n.inspirationApplyCommandFailed,
        null => l10n.inspirationApplyFailed,
      };
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context).inspirationLoading,
    liveRegion: true,
    child: ListView(
      padding: const EdgeInsets.all(PicPacSpacing.lg),
      physics: const NeverScrollableScrollPhysics(),
      children: const <Widget>[
        SkeletonBox(height: 320, radius: PicPacRadii.card),
        SizedBox(height: PicPacSpacing.xl),
        SkeletonBox(height: 24, width: 200),
        SizedBox(height: PicPacSpacing.md),
        SkeletonBox(height: 16, width: 140),
        SizedBox(height: PicPacSpacing.xl),
        SkeletonBox(height: 48, radius: PicPacRadii.field),
      ],
    ),
  );
}
