import 'dart:io';

import 'package:design_core/design_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../_shared/application/design_session.dart';
import '../../../_shared/application/frame_analyzer.dart';
import '../../../_shared/application/media_providers.dart';
import '../../../../core/presentation/text_tones.dart';
import '../../../../core/presentation/a11y.dart';

class EnhanceActions extends ConsumerStatefulWidget {
  const EnhanceActions({required this.designId, super.key});

  final String designId;

  @override
  ConsumerState<EnhanceActions> createState() => _EnhanceActionsState();
}

class _EnhanceActionsState extends ConsumerState<EnhanceActions> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(designSessionProvider(widget.designId)).value;
    if (state == null || state.document.photoCount == 0) {
      return const SizedBox.shrink();
    }
    final first = state.document.assets.first;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PicPacSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _PreviewThumb(
                  designId: widget.designId,
                  asset: first,
                  label: l10n.createEnhancePreviewBefore,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: PicPacSpacing.xs),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: PicPacColors.muted,
                  ),
                ),
                _PreviewThumb(
                  designId: widget.designId,
                  asset: first,
                  label: l10n.createEnhancePreviewAfter,
                  enhanced: true,
                ),
                const SizedBox(width: PicPacSpacing.md),
                Expanded(
                  child: Text(
                    l10n.createEnhancePreviewHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: FunnelText.secondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: PicPacSpacing.md),
            MinTapTarget(
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _enhance(state),
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_outlined, size: 20),
                label: Text(_busy ? l10n.loading : l10n.createEnhanceAll),
              ),
            ),
            const SizedBox(height: PicPacSpacing.xs),
            MinTapTarget(
              child: OutlinedButton.icon(
                onPressed: state.canUndo && !_busy ? () => _reset() : null,
                icon: const Icon(Icons.settings_backup_restore, size: 20),
                label: Text(l10n.createResetToImported),
              ),
            ),
            const SizedBox(height: PicPacSpacing.xxs),
            Text(
              l10n.createResetToImportedHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: FunnelText.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enhance(DesignSessionState state) async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final cache = ref.read(designAssetCacheProvider);
    final analyzer = ref.read(frameAnalyzerProvider);
    final analyses = <String, PhotoAnalysis>{};

    try {
      for (final asset in state.document.assets) {
        if (!mounted) return;
        final file = await cache.fileFor(widget.designId, asset.sha256);
        if (file == null) continue;
        final stats = await analyzer.analyze(file.path);
        if (stats == null) continue;
        final analysis = PhotoAnalysis.tryOf(stats);
        if (analysis != null) analyses[asset.id] = analysis;
      }
      if (!mounted) return;
      final outcome = ref
          .read(designSessionProvider(widget.designId).notifier)
          .enhanceAll(analyses);
      if (outcome.failed) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
        return;
      }
      if (outcome.applied == 0) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              outcome.alreadyEnhanced > 0
                  ? l10n.createEnhanceAlready
                  : l10n.createEnhanceFailed,
            ),
          ),
        );
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.createEnhanceApplied(outcome.applied)),
          action: SnackBarAction(
            label: l10n.createEnhanceUndo,
            onPressed: () => ref
                .read(designSessionProvider(widget.designId).notifier)
                .undo(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(designSessionProvider(widget.designId).notifier);
    notifier.resetToImported();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.createResetToImported),
          action: SnackBarAction(
            label: l10n.createEnhanceUndo,
            onPressed: notifier.undo,
          ),
        ),
      );
  }
}

class _PreviewThumb extends ConsumerWidget {
  const _PreviewThumb({
    required this.designId,
    required this.asset,
    required this.label,
    this.enhanced = false,
  });

  final String designId;
  final PhotoAsset asset;
  final String label;
  final bool enhanced;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cache = ref.watch(designAssetCacheProvider);
    return Semantics(
      image: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(PicPacRadii.sm),
            child: SizedBox(
              width: 48,
              height: 48,
              child: FutureBuilder<File?>(
                future: cache.fileFor(designId, asset.sha256),
                builder: (context, snapshot) {
                  final file = snapshot.data;
                  if (file == null) {
                    return const ColoredBox(color: PicPacColors.fillStone);
                  }
                  final image = Image.file(
                    file,
                    fit: BoxFit.cover,
                    cacheWidth: 144,
                    filterQuality: FilterQuality.low,
                    errorBuilder: (context, error, stack) =>
                        const ColoredBox(color: PicPacColors.fillStone),
                  );
                  if (!enhanced) return image;
                  return ColorFiltered(
                    colorFilter: ColorFilter.matrix(_exampleMatrix),
                    child: image,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: FunnelText.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

final List<double> _exampleMatrix = AdjustmentMatrix.encoded(
  const PhotoAdjustment(exposure: 0.18, contrast: 8, temperature: 10),
);
