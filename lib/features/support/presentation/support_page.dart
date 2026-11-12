import 'dart:async';

import 'package:api_contract/api_contract.dart' hide TextAlign;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/offline/offline_queue_listener.dart';
import '../../../core/session/session_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../../_shared/application/async_retry.dart';
import '../../../core/presentation/a11y.dart';
import '../../../core/presentation/failure_text.dart';
import '../../../core/presentation/format.dart';
import '../../../core/presentation/state_views.dart';
import '../../../core/presentation/text_tones.dart';
import '../application/support_controllers.dart';
import 'support_labels.dart';
import 'widgets/new_ticket_sheet.dart';

class SupportPage extends ConsumerWidget {
  const SupportPage({this.ticketId, super.key});

  final String? ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ticketId == null ? const _InboxView() : _ThreadView(ticketId: ticketId!);
}

class _InboxView extends ConsumerWidget {
  const _InboxView();

  Future<void> _compose(BuildContext context, WidgetRef ref) async {
    ref.read(ticketComposerProvider.notifier).reset();
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const NewTicketSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionControllerProvider);
    final inbox = ref.watch(supportInboxProvider);
    final supportMode = session.isSupportAgent;
    return Scaffold(
      appBar: AppBar(
        title: Text(supportMode ? l10n.supportAgentMode : l10n.supportTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.actionRetry,
            onPressed: () => ref.invalidate(supportInboxProvider),
            icon: const Icon(Icons.refresh),
          ),
          if (!supportMode)
            IconButton(
              tooltip: l10n.supportNewTicket,
              onPressed: () => _compose(context, ref),
              icon: const Icon(Icons.add_comment_outlined),
            ),
          const SizedBox(width: PicPacSpacing.xs),
        ],
      ),
      body: OfflineQueueListener(
        child: !session.isAccount
            ? EmptyView(
                title: l10n.supportTitle,
                body: l10n.supportLoginRequired,
                icon: Icons.support_agent_outlined,
                action: FilledButton(
                  onPressed: () =>
                      context.push(AppRoutes.loginFor(AppRoutes.support)),
                  child: Text(l10n.actionLogin),
                ),
              )
            : switch (inbox) {
                AsyncData<SupportInbox>(:final value) =>
                  value.isEmpty
                      ? EmptyView(
                          title: supportMode
                              ? l10n.supportEmptyAgentTitle
                              : l10n.supportEmptyTitle,
                          body: supportMode
                              ? l10n.supportEmptyAgentBody
                              : l10n.supportEmptyBody,
                          icon: Icons.mark_email_read_outlined,
                          action: supportMode
                              ? null
                              : FilledButton(
                                  onPressed: () => _compose(context, ref),
                                  child: Text(l10n.supportNewTicket),
                                ),
                        )
                      : RefreshIndicator(
                          color: PicPacColors.accent,
                          onRefresh: () async {
                            await ref
                                .read(supportInboxProvider.notifier)
                                .reload();
                          },
                          child: ListView.separated(
                            padding: const EdgeInsets.all(PicPacSpacing.lg),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount:
                                value.tickets.length + (supportMode ? 1 : 0),
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: PicPacSpacing.md),
                            itemBuilder: (context, index) {
                              if (supportMode && index == 0) {
                                return const _AgentBanner();
                              }
                              final position = supportMode ? index - 1 : index;
                              return _TicketCard(
                                ticket: value.tickets[position],
                              );
                            },
                          ),
                        ),
                AsyncError<SupportInbox>(:final error) => FailureView(
                  failure: failureOr(error),
                  onRetry: () => ref.invalidate(supportInboxProvider),
                  onLogin: () =>
                      context.push(AppRoutes.loginFor(AppRoutes.support)),
                ),
                _ => const CardListSkeleton(),
              },
      ),
    );
  }
}

class _AgentBanner extends StatelessWidget {
  const _AgentBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(PicPacSpacing.md),
        decoration: BoxDecoration(
          color: PicPacColors.fillBlue,
          borderRadius: BorderRadius.circular(PicPacRadii.field),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.shield_outlined, size: 20),
            const SizedBox(width: PicPacSpacing.sm),
            Expanded(
              child: Text(
                l10n.supportAgentModeHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fmt = Fmt.of(context);
    final orderId = ticket.orderId;
    return FocusRing(
      child: Semantics(
        container: true,
        button: true,
        label: a11yTicketCardLabel(
          l10n,
          subject: ticket.subject,
          status: ticketStatusLabel(l10n, ticket.status),
        ),
        onTap: () => context.push('${AppRoutes.support}/${ticket.id}'),
        excludeSemantics: true,
        child: Material(
          color: PicPacColors.surface,
          borderRadius: BorderRadius.circular(PicPacRadii.card),
          child: InkWell(
            borderRadius: BorderRadius.circular(PicPacRadii.card),
            onTap: () => context.push('${AppRoutes.support}/${ticket.id}'),
            child: Ink(
              padding: const EdgeInsets.all(PicPacSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(PicPacRadii.card),
                border: Border.all(color: PicPacColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          ticket.subject,
                          style: theme.textTheme.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: PicPacSpacing.sm),
                      Flexible(
                        child: StatusChip(
                          label: ticketStatusLabel(l10n, ticket.status),
                          tone: ticketStatusTone(ticket.status),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: PicPacSpacing.xs),
                  Text(
                    l10n.supportUpdatedAt(fmt.dateTime(ticket.updatedAt)),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: FunnelText.secondary,
                    ),
                  ),
                  const SizedBox(height: PicPacSpacing.md),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          ticketTypeLabel(l10n, ticket.type),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: FunnelText.secondary,
                          ),
                        ),
                      ),
                      if (orderId != null)
                        const Icon(
                          Icons.receipt_long_outlined,
                          size: 18,
                          color: FunnelText.secondary,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThreadView extends ConsumerWidget {
  const _ThreadView({required this.ticketId});

  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final thread = ref.watch(ticketThreadProvider(ticketId));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          thread.value?.subject ?? l10n.supportTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: switch (thread) {
        AsyncData<SupportTicket>(:final value) => _ThreadBody(ticket: value),
        AsyncError<SupportTicket>(:final error) =>
          failureOr(error).code == ApiErrorCode.forbidden
              ? EmptyView(
                  title: l10n.supportForeignTicket,
                  body: l10n.supportForeignTicketBody,
                  icon: Icons.lock_outline,
                  action: FilledButton(
                    onPressed: () => context.go(AppRoutes.support),
                    child: Text(l10n.actionBack),
                  ),
                )
              : FailureView(
                  failure: failureOr(error),
                  onRetry: () => ref.invalidate(ticketThreadProvider(ticketId)),
                  onLogin: () =>
                      context.push(AppRoutes.loginFor(AppRoutes.support)),
                ),
        _ => const CardListSkeleton(),
      },
    );
  }
}

class _ThreadBody extends ConsumerStatefulWidget {
  const _ThreadBody({required this.ticket});

  final SupportTicket ticket;

  @override
  ConsumerState<_ThreadBody> createState() => _ThreadBodyState();
}

class _ThreadBodyState extends ConsumerState<_ThreadBody> {
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    final outcome = await ref
        .read(ticketThreadProvider(widget.ticket.id).notifier)
        .send(body);
    if (!mounted) return;
    setState(() => _sending = false);
    final l10n = AppLocalizations.of(context);
    switch (outcome.status) {
      case MessageStatus.sent:
        _text.clear();
        _scrollToEnd();
      case MessageStatus.queued:
        _text.clear();
        _showMessage(l10n.supportQueued);
        _scrollToEnd();
      case MessageStatus.failed:
        final failure = outcome.failure;
        _showMessage(
          failure == null
              ? l10n.supportSendFailed
              : '${l10n.supportSendFailed}: ${failureText(l10n, failure)}',
        );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final reduceMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (reduceMotion) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
        return;
      }
      unawaited(
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fmt = Fmt.of(context);
    final role = ref.watch(sessionControllerProvider).role;
    final supportMode = role == UserRole.supportAgent;
    final ticket = widget.ticket;
    final canReply = ticket.status.isOpen;
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.all(PicPacSpacing.lg),
            children: <Widget>[
              Row(
                children: <Widget>[
                  StatusChip(
                    label: ticketStatusLabel(l10n, ticket.status),
                    tone: ticketStatusTone(ticket.status),
                  ),
                  const SizedBox(width: PicPacSpacing.sm),
                  Expanded(
                    child: Text(
                      ticketTypeLabel(l10n, ticket.type),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: FunnelText.secondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PicPacSpacing.md),
              for (final message in ticket.messages)
                Padding(
                  padding: const EdgeInsets.only(bottom: PicPacSpacing.md),
                  child: _MessageBubble(
                    message: message,
                    own: message.authorRole == role,
                    author: message.authorRole == role
                        ? l10n.supportAuthorYou
                        : message.authorRole == UserRole.supportAgent
                        ? l10n.supportAuthorSupport
                        : l10n.supportAuthorCustomer,
                    time: fmt.dateTime(message.createdAt),
                    queued: message.id.startsWith('local_'),
                  ),
                ),
            ],
          ),
        ),
        if (!canReply)
          Padding(
            padding: const EdgeInsets.all(PicPacSpacing.lg),
            child: Text(
              l10n.supportTicketClosed,
              style: theme.textTheme.bodySmall?.copyWith(
                color: FunnelText.secondary,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                PicPacSpacing.lg,
                PicPacSpacing.sm,
                PicPacSpacing.sm,
                PicPacSpacing.sm,
              ),
              decoration: const BoxDecoration(
                color: PicPacColors.surface,
                border: Border(top: BorderSide(color: PicPacColors.border)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      key: const Key('support-reply'),
                      controller: _text,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: supportMode
                            ? l10n.supportReplyHintAgent
                            : l10n.supportReplyHint,
                      ),
                    ),
                  ),
                  const SizedBox(width: PicPacSpacing.sm),
                  SizedBox(
                    width: kMinTouchTarget,
                    height: kMinTouchTarget,
                    child: IconButton.filled(
                      tooltip: l10n.supportSend,
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.own,
    required this.author,
    required this.time,
    required this.queued,
  });

  final TicketMessage message;
  final bool own;
  final String author;
  final String time;
  final bool queued;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: own ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          padding: const EdgeInsets.all(PicPacSpacing.md),
          decoration: BoxDecoration(
            color: own ? PicPacColors.fillBeige : PicPacColors.surface,
            borderRadius: BorderRadius.circular(PicPacRadii.field),
            border: Border.all(color: PicPacColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(author, style: theme.textTheme.labelMedium),
                  const SizedBox(width: PicPacSpacing.sm),
                  Expanded(
                    child: Text(
                      time,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: FunnelText.secondary,
                      ),
                    ),
                  ),
                  if (queued)
                    Tooltip(
                      message: l10n.supportQueued,
                      child: const Icon(
                        Icons.schedule,
                        size: 16,
                        color: FunnelText.secondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: PicPacSpacing.xs),
              Text(message.body, style: theme.textTheme.bodyMedium),
              if (queued) ...<Widget>[
                const SizedBox(height: PicPacSpacing.xs),
                Text(
                  l10n.supportMessageQueued,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: FunnelText.secondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
