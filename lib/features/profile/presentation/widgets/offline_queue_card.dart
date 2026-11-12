import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/offline/offline_queue.dart';
import '../../../../core/offline/pending_actions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/presentation/format.dart';
import '../../../../core/presentation/state_views.dart';
import '../../../../core/presentation/text_tones.dart';
import '../../../../core/presentation/a11y.dart';

class OfflineQueueCard extends ConsumerStatefulWidget {
  const OfflineQueueCard({super.key});

  @override
  ConsumerState<OfflineQueueCard> createState() => _OfflineQueueCardState();
}

class _OfflineQueueCardState extends ConsumerState<OfflineQueueCard> {
  bool _running = false;

  Future<void> _run({bool manual = false}) async {
    if (_running) return;
    setState(() => _running = true);
    final report = await ref
        .read(pendingActionsControllerProvider.notifier)
        .run(manual: manual);
    if (!mounted) return;
    setState(() => _running = false);
    _announce(report);
  }

  Future<void> _retry(String id) async {
    if (_running) return;
    setState(() => _running = true);
    final report = await ref
        .read(pendingActionsControllerProvider.notifier)
        .retry(id);
    if (!mounted) return;
    setState(() => _running = false);
    _announce(report);
  }

  void _announce(OfflineQueueReport report) {
    final l10n = AppLocalizations.of(context);
    final String message;
    if (report.orderNumbers.isNotEmpty) {
      message = l10n.profileQueueOrderSent(report.orderNumbers.first);
    } else if (report.sent > 0) {
      message = l10n.profileQueueSent(report.sent);
    } else if (report.remaining > 0) {
      message = l10n.profileQueueStillQueued(report.remaining);
    } else {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final queue = ref.watch(pendingActionsControllerProvider);
    final items = queue.value ?? const <QueuedAction>[];
    final fmt = Fmt.of(context);
    return SectionCard(
      title: l10n.profileQueueTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (queue.isLoading)
            const SkeletonBox(height: 48)
          else if (items.isEmpty) ...<Widget>[
            Text(l10n.profileQueueEmpty),
            const SizedBox(height: PicPacSpacing.xs),
            Text(
              l10n.profileQueueEmptyHint,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: FunnelText.secondary),
            ),
          ] else ...<Widget>[
            for (final item in items) ...<Widget>[
              _QueueRow(
                item: item,
                time: fmt.dateTime(item.createdAt),
                onRetry: _running ? null : () => _retry(item.id),
              ),
              if (item != items.last) const Divider(height: PicPacSpacing.xl),
            ],
            const SizedBox(height: PicPacSpacing.md),
            MinTapTarget(
              child: OutlinedButton.icon(
                onPressed: _running ? null : () => _run(manual: true),
                icon: _running
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(l10n.profileQueueRetryAll),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.item,
    required this.time,
    required this.onRetry,
  });

  final QueuedAction item;
  final String time;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final failed = item.isExhausted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _kindLabel(l10n, item.kind),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: PicPacSpacing.xxs),
              Text(
                '$time · ${l10n.profileQueueAttempts(item.attempts)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: FunnelText.secondary,
                ),
              ),
              const SizedBox(height: PicPacSpacing.xs),
              StatusChip(
                label: failed
                    ? l10n.profileQueueFailed
                    : l10n.profileQueueQueued,
                tone: failed ? ChipTone.danger : ChipTone.progress,
              ),
            ],
          ),
        ),
        MinTapTarget(
          minWidth: kMinTouchTarget,
          child: IconButton(
            tooltip: l10n.profileQueueRetry,
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
          ),
        ),
      ],
    );
  }

  static String _kindLabel(AppLocalizations l10n, PendingActionKind kind) =>
      switch (kind) {
        PendingActionKind.checkout => l10n.profileQueueItemCheckout,
        PendingActionKind.createTicket => l10n.profileQueueItemTicket,
        PendingActionKind.postMessage => l10n.profileQueueItemMessage,
        PendingActionKind.unknown => l10n.profileQueueItemUnknown,
      };
}
