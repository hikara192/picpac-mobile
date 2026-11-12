import 'package:api_contract/api_contract.dart' hide TextAlign;
import 'package:design_core/design_core.dart' hide TextAlign;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/motion.dart';
import '../../../app/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/orders/preflight_ack.dart';
import '../../../l10n/app_localizations.dart';
import '../application/preflight_controller.dart';
import '../application/async_retry.dart';
import '../application/design_session.dart';
import '../../../core/presentation/a11y.dart';
import '../../../core/presentation/failure_text.dart';
import 'preflight_messages.dart';
import 'sheet_scene.dart';
import '../../../core/presentation/text_tones.dart';

class PreflightOrderBar extends ConsumerStatefulWidget {
  const PreflightOrderBar({required this.designId, super.key});

  final String designId;

  @override
  ConsumerState<PreflightOrderBar> createState() => _PreflightOrderBarState();
}

class _PreflightOrderBarState extends ConsumerState<PreflightOrderBar> {
  bool _adding = false;

  Future<void> _order({bool force = false}) async {
    if (_adding) return;
    setState(() => _adding = true);
    try {
      final local = ref.read(designSessionProvider(widget.designId)).value;
      if (local != null && local.localOnly) {
        final promoted = await ref
            .read(designSessionProvider(widget.designId).notifier)
            .promoteToServer();
        if (!mounted) return;
        if (promoted case Err<String>(:final error)) {
          _showFailure(error);
          return;
        }
      }
      await ref.read(designSessionProvider(widget.designId).notifier).syncNow();
      if (!mounted) return;
      ref.invalidate(preflightProvider(widget.designId));
      PreflightView view;
      try {
        view = await ref.read(preflightProvider(widget.designId).future);
      } on Object catch (error) {
        if (!mounted) return;
        _showFailure(failureOr(error));
        return;
      }
      if (!mounted) return;
      if (!force && !view.report.canOrder) {
        await _openIssues(view);
        return;
      }
      final failure = await ref
          .read(preflightProvider(widget.designId).notifier)
          .addToCart();
      if (!mounted) return;
      if (failure != null) {
        if (isPreflightBlocked(failure)) {
          ref.invalidate(preflightProvider(widget.designId));
          final blocked = await ref
              .read(preflightProvider(widget.designId).future)
              .catchError((Object _) => view);
          if (!mounted) return;
          await _openIssues(blocked);
          return;
        }
        _showFailure(failure);
        return;
      }
      context.go(AppRoutes.cart);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  void _showFailure(Failure failure) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.preflightAddFailed}: ${failureText(l10n, failure)}',
          ),
        ),
      );
  }

  Future<void> _openIssues(PreflightView view) async {
    final session = ref.read(designSessionProvider(widget.designId)).value;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: PicPacColors.surface,
      sheetAnimationStyle: AnimationStyle(
        duration: motionDuration(context, Motion.sheet),
        reverseDuration: motionDuration(context, Motion.reveal),
      ),
      builder: (sheetContext) => _IssuesSheet(
        designId: widget.designId,
        view: view,
        session: session,
        onAcknowledge: _acknowledge,
        onOrder: () {
          Navigator.of(sheetContext).pop();
          _order(force: true);
        },
      ),
    );
  }

  Future<void> _acknowledge() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.preflightOverrideTitle),
        content: Text(l10n.preflightOverrideBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.preflightOverrideConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref.read(preflightProvider(widget.designId).notifier).acknowledge();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(l10n.preflightOverrideRecorded)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(designSessionProvider(widget.designId)).value;
    final preflight = ref.watch(preflightProvider(widget.designId)).value;
    final report = preflight?.report;
    final empty = session == null || session.document.photoCount == 0;
    final issues = report?.issues ?? const <PreflightIssue>[];
    final blocking = report?.blockingCount ?? 0;
    final warnings = report?.warningCount ?? 0;
    final (icon, tone, label) = blocking > 0
        ? (
            Icons.error_outline,
            PicPacColors.accentText,
            l10n.preflightStatusBlocking(blocking),
          )
        : warnings > 0
        ? (
            Icons.warning_amber_outlined,
            PicPacColors.inkStrong,
            l10n.preflightStatusWarnings(issues.length),
          )
        : (Icons.info_outline, PicPacColors.muted, l10n.preflightStatusClean);

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
          Row(
            children: <Widget>[
              _StatusKnob(
                icon: icon,
                tone: tone,
                label: label,
                count: issues.length,
                onTap: preflight == null || issues.isEmpty
                    ? null
                    : () => _openIssues(preflight),
              ),
              const SizedBox(width: PicPacSpacing.sm),
              Expanded(
                child: MinTapTarget(
                  child: FilledButton(
                    key: const Key('create-order-cta'),
                    onPressed: empty || _adding ? null : () => _order(),
                    child: Text(
                      _adding ? l10n.preflightAdding : l10n.createOrder,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (empty) ...<Widget>[
            const SizedBox(height: PicPacSpacing.xs),
            Text(
              l10n.createOrderNeedsPhotos,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: FunnelText.secondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusKnob extends StatelessWidget {
  const _StatusKnob({
    required this.icon,
    required this.tone,
    required this.label,
    required this.count,
    this.onTap,
  });

  final IconData icon;
  final Color tone;
  final String label;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kMinTouchTarget,
      height: kMinTouchTarget,
      child: Tooltip(
        message: label,
        child: InkResponse(
          key: const Key('create-preflight-status'),
          onTap: onTap,
          radius: 24,
          child: Semantics(
            button: onTap != null,
            label: label,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Icon(icon, size: 24, color: tone),
                if (count > 0)
                  Positioned(
                    right: 0,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: BoxDecoration(
                        color: PicPacColors.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: Colors.white, height: 1.4),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IssuesSheet extends ConsumerWidget {
  const _IssuesSheet({
    required this.designId,
    required this.view,
    required this.session,
    required this.onAcknowledge,
    required this.onOrder,
  });

  final String designId;
  final PreflightView view;
  final DesignSessionState? session;
  final Future<void> Function() onAcknowledge;
  final VoidCallback onOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final live = ref.watch(preflightProvider(designId)).value ?? view;
    final report = live.report;
    final issues = report.issues;
    final blocking = report.blockingCount;
    final current = session;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(PicPacSpacing.lg),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.preflightTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: l10n.actionClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          if (current != null && current.spreads.isNotEmpty) ...<Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SheetScene(
                designId: designId,
                document: current.document,
                spread: current.spreads.first,
                template: current.templateOf(current.spreads.first),
                spec: current.spec,
                maxSide: 2048,
                slotDecodeTargets: true,
              ),
            ),
            const SizedBox(height: PicPacSpacing.md),
          ],
          if (issues.isEmpty)
            Text(
              l10n.preflightCleanTitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: PicPacColors.inkStrong,
              ),
            )
          else ...<Widget>[
            Text(
              l10n.preflightIssuesTitle(issues.length),
              style: theme.textTheme.titleSmall,
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
                onTap: () {
                  final spreadId = issue.spreadId;
                  final slotId = issue.slotId;
                  if (spreadId == null || slotId == null) return;
                  Navigator.of(context).pop();
                  context.push(
                    AppRoutes.editorFor(designId),
                    extra: EditorFocus(spreadId: spreadId, slotId: slotId),
                  );
                },
              ),
            const SizedBox(height: PicPacSpacing.md),
            if (!report.canOrder)
              MinTapTarget(
                child: FilledButton(
                  key: const Key('preflight-ack-and-order'),
                  onPressed: () => onAcknowledge(),
                  child: Text(l10n.preflightAckAndOrder),
                ),
              )
            else
              MinTapTarget(
                child: FilledButton(
                  onPressed: onOrder,
                  child: Text(l10n.createOrder),
                ),
              ),
          ],
        ],
      ),
    );
  }

  int _sheetIndexOf(PreflightIssue issue) {
    final doc = session?.document;
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
    required this.onTap,
  });

  final PreflightIssue issue;
  final int sheetIndex;
  final VoidCallback onTap;

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
        onTap: actionable ? onTap : null,
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
                const Icon(
                  Icons.open_in_new,
                  size: 18,
                  color: PicPacColors.muted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
