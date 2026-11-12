import 'package:design_core/design_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../_shared/application/async_retry.dart';
import '../../_shared/application/design_session.dart';
import '../../_shared/application/pdf_export_controller.dart';
import '../../../core/presentation/export_messages.dart';
import '../../../core/presentation/failure_text.dart';
import '../../_shared/presentation/preflight_messages.dart';
import '../../../core/presentation/state_views.dart';
import '../../../core/presentation/text_tones.dart';
import '../application/preflight_controller.dart';
import '../../../core/presentation/a11y.dart';

class PreflightPage extends ConsumerStatefulWidget {
  const PreflightPage({required this.designId, super.key});

  final String designId;

  @override
  ConsumerState<PreflightPage> createState() => _PreflightPageState();
}

class _PreflightPageState extends ConsumerState<PreflightPage> {
  bool _adding = false;
  bool _prepared = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_prepare);
  }

  Future<void> _prepare() async {
    final provider = designSessionProvider(widget.designId);
    try {
      await ref.read(provider.future);
    } on Object {
    }
    if (!mounted) return;
    await ref.read(provider.notifier).syncNow();
    if (!mounted) return;
    setState(() => _prepared = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!_prepared) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.preflightTitle)),
        body: const CardListSkeleton(items: 2),
      );
    }
    final provider = preflightProvider(widget.designId);
    final preflight = ref.watch(provider);
    final session = ref.watch(designSessionProvider(widget.designId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.preflightTitle)),
      body: switch (preflight) {
        AsyncData<PreflightView>(:final value) => _Body(
          view: value,
          document: session.value?.document,
          onFix: _openSlot,
        ),
        AsyncError<PreflightView>(:final error) => FailureView(
          failure: failureOr(error),
          onRetry: () => ref.invalidate(provider),
          onLogin: () => context.push(AppRoutes.login),
        ),
        _ => const CardListSkeleton(items: 2),
      },
      bottomNavigationBar: switch (preflight) {
        AsyncData<PreflightView>(:final value) => _BottomBar(
          designId: widget.designId,
          view: value,
          adding: _adding,
          onOverride: _confirmOverride,
          onAddToCart: _addToCart,
        ),
        _ => null,
      },
    );
  }

  void _openSlot(PreflightIssue issue) {
    final spreadId = issue.spreadId;
    final slotId = issue.slotId;
    if (spreadId == null || slotId == null) return;
    context.push(
      AppRoutes.editorFor(widget.designId),
      extra: EditorFocus(spreadId: spreadId, slotId: slotId),
    );
  }

  Future<void> _confirmOverride() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.preflightOverrideTitle),
        content: Text(l10n.preflightOverrideBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.preflightOverrideConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref.read(preflightProvider(widget.designId).notifier).acknowledge();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.preflightOverrideRecorded)));
  }

  Future<void> _addToCart() async {
    setState(() => _adding = true);
    final failure = await ref
        .read(preflightProvider(widget.designId).notifier)
        .addToCart();
    if (!mounted) return;
    setState(() => _adding = false);
    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context).preflightAddFailed}: '
            '${failureText(AppLocalizations.of(context), failure)}',
          ),
        ),
      );
      return;
    }
    context.go(AppRoutes.cart);
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.view,
    required this.document,
    required this.onFix,
  });

  final PreflightView view;
  final DesignDocument? document;
  final void Function(PreflightIssue issue) onFix;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final report = view.report;
    final issues = report.issues;
    final blocking = report.blockingCount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        PicPacSpacing.lg,
        PicPacSpacing.md,
        PicPacSpacing.lg,
        PicPacSpacing.xxl,
      ),
      children: <Widget>[
        if (!view.usesServer)
          _Banner(
            tone: PicPacColors.fillBeige,
            icon: Icons.cloud_off_outlined,
            text: l10n.preflightOffline,
          ),
        if (view.serverDifferences.isNotEmpty)
          _Banner(
            tone: PicPacColors.fillBlue,
            icon: Icons.compare_arrows,
            text: l10n.preflightServerMismatch(view.serverDifferences.length),
          ),
        const SizedBox(height: PicPacSpacing.md),
        if (issues.isEmpty)
          EmptyView(
            title: l10n.preflightCleanTitle,
            body: l10n.preflightCleanBody,
            icon: Icons.check_circle_outline,
          )
        else ...<Widget>[
          Text(
            l10n.preflightIssuesTitle(issues.length),
            style: theme.textTheme.titleMedium,
          ),
          if (blocking > 0) ...<Widget>[
            const SizedBox(height: PicPacSpacing.xxs),
            Text(
              l10n.preflightBlockingNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: PicPacColors.accentText,
              ),
            ),
          ],
          const SizedBox(height: PicPacSpacing.md),
          for (final issue in issues)
            _IssueTile(
              issue: issue,
              sheetIndex: _sheetIndexOf(issue),
              onFix: () => onFix(issue),
            ),
        ],
      ],
    );
  }

  int _sheetIndexOf(PreflightIssue issue) {
    final doc = document;
    final spreadId = issue.spreadId;
    if (doc == null || spreadId == null) return 0;
    final index = doc.spreads.indexWhere((spread) => spread.id == spreadId);
    return index < 0 ? 0 : index;
  }
}

class _IssueTile extends StatelessWidget {
  const _IssueTile({
    required this.issue,
    required this.sheetIndex,
    required this.onFix,
  });

  final PreflightIssue issue;
  final int sheetIndex;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final blocking = issue.isBlocking;
    final hint = preflightIssueHint(l10n, issue, sheetIndex);
    final actionable = issue.spreadId != null && issue.slotId != null;
    return Container(
      margin: const EdgeInsets.only(bottom: PicPacSpacing.sm),
      decoration: BoxDecoration(
        color: blocking ? PicPacColors.accentSoft : PicPacColors.surface,
        borderRadius: BorderRadius.circular(PicPacRadii.card),
        border: Border.all(color: PicPacColors.border),
      ),
      child: InkWell(
        onTap: actionable ? onFix : null,
        borderRadius: BorderRadius.circular(PicPacRadii.card),
        child: Padding(
          padding: const EdgeInsets.all(PicPacSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                blocking ? Icons.error_outline : Icons.info_outline,
                size: 20,
                color: blocking
                    ? PicPacColors.accentText
                    : PicPacColors.inkStrong,
              ),
              const SizedBox(width: PicPacSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      preflightIssueText(l10n, issue),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: PicPacColors.inkStrong,
                      ),
                    ),
                    if (hint != null) ...<Widget>[
                      const SizedBox(height: PicPacSpacing.xxs),
                      Text(
                        hint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: FunnelText.secondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: PicPacSpacing.xxs),
                    Text(
                      l10n.preflightSheetBadge(sheetIndex + 1),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: FunnelText.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (actionable) ...<Widget>[
                const SizedBox(width: PicPacSpacing.xs),
                IconButton(
                  onPressed: onFix,
                  tooltip: l10n.preflightFixHint,
                  icon: const Icon(Icons.open_in_new, size: 20),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class PreflightShareButton extends ConsumerStatefulWidget {
  const PreflightShareButton({
    required this.designId,
    required this.enabled,
    super.key,
  });

  final String designId;

  final bool enabled;

  @override
  ConsumerState<PreflightShareButton> createState() =>
      _PreflightShareButtonState();
}

class _PreflightShareButtonState extends ConsumerState<PreflightShareButton> {
  Future<void> _share() async {
    final l10n = AppLocalizations.of(context);
    final failure = await ref
        .read(pdfExportProvider(widget.designId).notifier)
        .share();
    if (failure == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.preflightShareFailed}: '
            '${exportFailureText(l10n, failure)}',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state =
        ref.watch(pdfExportProvider(widget.designId)).value ??
        PdfExportState.idle;
    final busy = state.isBusy;
    final label = switch (state.phase) {
      PdfExportPhase.rendering => l10n.preflightSharePreparing(
        state.done,
        state.total,
      ),
      PdfExportPhase.sharing => l10n.preflightShareOpening,
      PdfExportPhase.idle => l10n.preflightSharePdf,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (busy) ...<Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(PicPacRadii.field),
            child: LinearProgressIndicator(
              value: state.phase == PdfExportPhase.rendering
                  ? state.progress
                  : null,
              minHeight: 3,
              color: PicPacColors.accent,
              backgroundColor: PicPacColors.fillBeige,
            ),
          ),
          const SizedBox(height: PicPacSpacing.xs),
        ],
        Tooltip(
          message: widget.enabled || busy ? '' : l10n.preflightShareBlocked,
          child: MinTapTarget(
            child: OutlinedButton.icon(
              key: const Key('preflight-share-pdf'),
              onPressed: widget.enabled && !busy ? _share : null,
              icon: const Icon(Icons.ios_share, size: 20),
              label: Text(label),
            ),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.tone, required this.icon, required this.text});

  final Color tone;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: PicPacSpacing.sm),
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
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: PicPacColors.inkStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.designId,
    required this.view,
    required this.adding,
    required this.onOverride,
    required this.onAddToCart,
  });

  final String designId;
  final PreflightView view;
  final bool adding;
  final VoidCallback onOverride;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final report = view.report;
    final blocked = !report.canOrder;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        PicPacSpacing.lg,
        PicPacSpacing.sm,
        PicPacSpacing.lg,
        PicPacSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PreflightShareButton(designId: designId, enabled: !blocked),
          const SizedBox(height: PicPacSpacing.sm),
          if (blocked)
            MinTapTarget(
              child: OutlinedButton(
                onPressed: onOverride,
                child: Text(l10n.preflightOverride),
              ),
            ),
          if (blocked) const SizedBox(height: PicPacSpacing.sm),
          MinTapTarget(
            child: FilledButton(
              onPressed: adding || blocked ? null : onAddToCart,
              child: Text(adding ? l10n.preflightAdding : l10n.preflightToCart),
            ),
          ),
        ],
      ),
    );
  }
}
