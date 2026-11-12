import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../_shared/application/async_retry.dart';
import '../../_shared/application/design_session.dart';
import '../../_shared/application/media_providers.dart';
import '../../../core/presentation/failure_text.dart';
import '../../_shared/presentation/preflight_order_bar.dart';
import '../../_shared/presentation/sheet_scene.dart';
import '../../../core/presentation/state_views.dart';
import '../../../core/presentation/text_tones.dart';
import '../application/import_controller.dart';
import 'widgets/enhance_actions.dart';
import 'widgets/guest_project_view.dart';
import 'widgets/import_notices.dart';
import 'widgets/layout_proposal_card.dart';
import 'widgets/photo_grid.dart';

class CreatePage extends ConsumerStatefulWidget {
  const CreatePage({required this.designId, super.key});

  final String designId;

  @override
  ConsumerState<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends ConsumerState<CreatePage>
    with WidgetsBindingObserver {
  bool _conflictDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      final session = ref.read(designSessionProvider(widget.designId)).value;
      if (session == null) return;
      ref.read(designSessionProvider(widget.designId).notifier).flush();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = designSessionProvider(widget.designId);
    final session = ref.watch(provider);

    ref.listen(provider, (previous, next) {
      final conflict =
          next.value?.sync == DesignSyncStatus.conflict &&
          previous?.value?.sync != DesignSyncStatus.conflict;
      if (conflict) _showConflict();
    });

    ref.listen(importControllerProvider(widget.designId), (previous, next) {
      final promoted = next.promotedDesignId;
      if (promoted == null ||
          promoted == previous?.promotedDesignId ||
          !mounted) {
        return;
      }
      final sessionNotifier = ref.read(provider.notifier);
      context.go(AppRoutes.createFor(promoted));
      sessionNotifier.discardLocalSnapshot();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.createTitle),
        actions: <Widget>[
          IconButton(
            onPressed: session.value?.canUndo ?? false
                ? () => ref.read(provider.notifier).undo()
                : null,
            tooltip: l10n.createUndo,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            onPressed: session.value?.canRedo ?? false
                ? () => ref.read(provider.notifier).redo()
                : null,
            tooltip: l10n.createRedo,
            icon: const Icon(Icons.redo),
          ),
          const SizedBox(width: PicPacSpacing.xs),
        ],
      ),
      body: switch (session) {
        AsyncData<DesignSessionState>(:final value) => _Body(
          state: value,
          designId: widget.designId,
        ),
        AsyncError<DesignSessionState>(:final error) =>
          failureOr(error).code == ApiErrorCode.forbidden
              ? GuestProjectView(designId: widget.designId)
              : FailureView(
                  failure: failureOr(error),
                  onRetry: () => ref.invalidate(provider),
                  onLogin: () => context.push(AppRoutes.login),
                ),
        _ => const CardListSkeleton(items: 2),
      },
      bottomNavigationBar: switch (session) {
        AsyncData<DesignSessionState>() => PreflightOrderBar(
          designId: widget.designId,
        ),
        _ => null,
      },
    );
  }

  Future<void> _showConflict() async {
    if (_conflictDialogOpen) return;
    _conflictDialogOpen = true;
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(designSessionProvider(widget.designId).notifier);
    final choice = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.createConflictTitle),
        content: Text(l10n.createConflictBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.createConflictKeepLocal),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.createConflictLoadServer),
          ),
        ],
      ),
    );
    _conflictDialogOpen = false;
    if (!mounted || choice == null) return;
    final failure = choice
        ? await notifier.loadServerVersion()
        : await notifier.keepLocalVersion();
    if (!mounted || failure == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(failureText(l10n, failure))));
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.state, required this.designId});

  final DesignSessionState state;
  final String designId;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  String? _selectedAssetId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = widget.state;
    final designId = widget.designId;
    final assets = state.document.assets;
    final firstSpread = state.spreads.isEmpty ? null : state.spreads.first;
    final importState = ref.watch(importControllerProvider(designId));
    final atLimit = state.isAtPhotoLimit;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        PicPacSpacing.lg,
        PicPacSpacing.md,
        PicPacSpacing.lg,
        PicPacSpacing.xxl,
      ),
      children: <Widget>[
        _SyncBanner(state: state),
        if (firstSpread != null) ...<Widget>[
          const SizedBox(height: PicPacSpacing.md),
          Text(
            l10n.createPreviewTitle(1, state.spreads.length),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: PicPacSpacing.sm),
          Container(
            padding: const EdgeInsets.all(PicPacSpacing.md),
            decoration: BoxDecoration(
              color: PicPacColors.surfaceMuted,
              borderRadius: BorderRadius.circular(PicPacRadii.card),
              border: Border.all(color: PicPacColors.border),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: Semantics(
                  label: l10n.createPreviewTitle(1, state.spreads.length),
                  image: true,
                  child: SheetScene(
                    designId: designId,
                    document: state.document,
                    spread: firstSpread,
                    template: state.templateOf(firstSpread),
                    spec: state.spec,
                    maxSide: 640,
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: PicPacSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.push(AppRoutes.editorFor(designId)),
            icon: const Icon(Icons.tune, size: 20),
            label: Text(l10n.createEditSheets),
          ),
        ),
        EnhanceActions(designId: designId),
        LayoutProposalCard(designId: designId),
        const SizedBox(height: PicPacSpacing.xl),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.createPhotosTitle,
                style: theme.textTheme.titleSmall,
              ),
            ),
            Text(
              state.photoLimit == null
                  ? '${assets.length}'
                  : l10n.createPhotosCount(assets.length, state.photoLimit!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: FunnelText.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: PicPacSpacing.sm),
        PhotoGrid(
          designId: designId,
          assets: assets,
          uploads: importState.pendingTiles,
          cache: ref.watch(designAssetCacheProvider),
          enabled: !importState.isBusy,
          canAdd: !atLimit && !importState.picking,
          selectedAssetId: _selectedAssetId,
          onSelect: (asset) => setState(() {
            _selectedAssetId = _selectedAssetId == asset.id ? null : asset.id;
          }),
          onAdd: () => ref
              .read(importControllerProvider(designId).notifier)
              .pickAndImport(),
          onCancelUpload: (task) => ref
              .read(importControllerProvider(designId).notifier)
              .cancel(task.localId),
          onRetryUpload: (task) => ref
              .read(importControllerProvider(designId).notifier)
              .retry(task.localId),
          onReorder: (from, to) => ref
              .read(designSessionProvider(designId).notifier)
              .reorderPhotos(from, to),
          onRemove: (asset) => _confirmRemove(context, asset),
        ),
        if (assets.length > 1) ...<Widget>[
          const SizedBox(height: PicPacSpacing.xs),
          Row(
            children: <Widget>[
              const Icon(
                Icons.drag_indicator,
                size: 16,
                color: PicPacColors.muted,
              ),
              const SizedBox(width: PicPacSpacing.xxs),
              Expanded(
                child: Text(
                  l10n.createReorderHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: FunnelText.secondary,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (atLimit) ...<Widget>[
          const SizedBox(height: PicPacSpacing.sm),
          Text(
            l10n.createLimitReached(state.photoLimit ?? 0),
            style: theme.textTheme.bodySmall?.copyWith(
              color: PicPacColors.accentText,
            ),
          ),
        ],
        if (state.missingPhotos > 0) ...<Widget>[
          const SizedBox(height: PicPacSpacing.sm),
          Text(
            l10n.createMinPhotos(state.format.minPhotos),
            style: theme.textTheme.bodySmall?.copyWith(
              color: FunnelText.secondary,
            ),
          ),
        ],
        ImportNotices(designId: designId),
      ],
    );
  }

  Future<void> _confirmRemove(BuildContext context, PhotoAsset asset) async {
    final l10n = AppLocalizations.of(context);
    final designId = widget.designId;
    final name = asset.id;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.createDeleteTitle),
        content: Text(l10n.createDeleteBody(name)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionRemove),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    ref.read(designSessionProvider(designId).notifier).removePhoto(asset.id);
    final remaining = ref
        .read(designSessionProvider(designId))
        .value
        ?.document
        .assets
        .map((item) => item.sha256)
        .toSet();
    if (remaining == null) return;
    await ref
        .read(designAssetCacheProvider)
        .collectGarbage(designId: designId, keep: remaining);
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.state});

  final DesignSessionState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (text, tone, icon) = state.localCopy
        ? (l10n.createLocalCopy, PicPacColors.fillBeige, Icons.devices_outlined)
        : switch (state.sync) {
            DesignSyncStatus.offline => (
              l10n.createOfflineBanner,
              PicPacColors.fillBeige,
              Icons.cloud_off_outlined,
            ),
            DesignSyncStatus.pending => (
              l10n.createSyncPending,
              PicPacColors.fillStone,
              Icons.sync_outlined,
            ),
            DesignSyncStatus.conflict => (
              l10n.createConflictTitle,
              PicPacColors.accentSoft,
              Icons.sync_problem_outlined,
            ),
            DesignSyncStatus.failed => (
              l10n.errorGeneric,
              PicPacColors.accentSoft,
              Icons.error_outline,
            ),
            DesignSyncStatus.saving => (
              l10n.createSyncSaving,
              PicPacColors.fillStone,
              Icons.sync,
            ),
            DesignSyncStatus.synced => (
              state.restoredFromCache
                  ? l10n.createDraftRestored
                  : l10n.createSyncSaved,
              PicPacColors.fillMint,
              Icons.check_circle_outline,
            ),
          };
    return Semantics(
      liveRegion: true,
      label: text,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: PicPacSpacing.md,
          vertical: PicPacSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: tone,
          borderRadius: BorderRadius.circular(PicPacRadii.field),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 18, color: PicPacColors.inkStrong),
            const SizedBox(width: PicPacSpacing.sm),
            Expanded(
              child: Text(
                state.localCopy
                    ? '${l10n.createLocalCopy}. ${l10n.createLocalCopyHint}'
                    : text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: PicPacColors.inkStrong,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
