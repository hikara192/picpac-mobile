import 'package:api_contract/api_contract.dart' hide TextAlign;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../payment_controller.dart';
import '../payment_flow.dart';
import '../payment_method.dart';
import '../../core/presentation/a11y.dart';
import '../../core/presentation/format.dart';
import '../../core/presentation/state_views.dart';
import '../../core/presentation/text_tones.dart';
import 'payment_messages.dart';
import 'payment_receipt_page.dart';

Future<void> showPaymentSheet(
  BuildContext context, {
  required Order order,
}) async {
  final opener = FocusManager.instance.primaryFocus;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: PicPacColors.background,
    builder: (_) => PaymentSheet(order: order),
  );
  if (opener != null && opener.context != null) opener.requestFocus();
}

Future<void> showPaymentAfterCheckout(BuildContext context, Order order) async {
  if (paymentCallToAction(order) != PaymentCallToAction.pay) return;
  final navigator = Navigator.of(context, rootNavigator: true);
  await SchedulerBinding.instance.endOfFrame;
  if (!navigator.mounted) return;
  await showPaymentSheet(navigator.context, order: order);
}

class PaymentSheet extends ConsumerStatefulWidget {
  const PaymentSheet({required this.order, super.key});

  final Order order;

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet>
    with WidgetsBindingObserver {
  final FocusNode _titleFocus = FocusNode(debugLabel: 'payment-sheet-title');

  final FocusNode _resultFocus = FocusNode(debugLabel: 'payment-sheet-status');

  PaymentOrderRef get _orderRef => PaymentOrderRef(
    orderId: widget.order.id,
    currency: widget.order.totals.total.currency,
  );

  PaymentController get _controller =>
      ref.read(paymentControllerProvider(_orderRef).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.loadMethods();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _titleFocus.dispose();
    _resultFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    _controller.pollNow();
  }

  Future<void> _openReceipt() async {
    await _controller.loadReceipt();
    if (!mounted) return;
    final state = ref.read(paymentControllerProvider(_orderRef));
    final receipt = state.receipt;
    if (receipt != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PaymentReceiptPage(receipt: receipt),
        ),
      );
      return;
    }
    final failure = state.receiptFailure;
    if (failure != null) {
      _snack(paymentFailureText(AppLocalizations.of(context), failure));
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fmt = Fmt.of(context);
    final provider = paymentControllerProvider(_orderRef);
    final state = ref.watch(provider);
    ref.listen(provider, (previous, next) {
      final before = previous?.flow.phase;
      final after = next.flow.phase;
      if (previous != null &&
          after == PaymentPhase.succeeded &&
          before != PaymentPhase.succeeded) {
        announceToScreenReader(context, l10n.paymentPaid);
        if (mounted) _resultFocus.requestFocus();
      }
      final failure = next.flow.failure;
      if (failure != null && failure != previous?.flow.failure) {
        announceToScreenReader(context, paymentFailureText(l10n, failure));
      }
    });
    final flow = state.flow;
    final intent = flow.intent;
    final amount = intent?.amount ?? widget.order.totals.total;
    final choosing = intent == null && !flow.isTerminal;

    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(
                      PicPacSpacing.lg,
                      0,
                      PicPacSpacing.lg,
                      PicPacSpacing.md,
                    ),
                    children: <Widget>[
                      Focus(
                        focusNode: _titleFocus,
                        autofocus: true,
                        skipTraversal: true,
                        child: Semantics(
                          header: true,
                          child: Text(
                            l10n.paymentPanelTitle,
                            style: theme.textTheme.headlineSmall,
                          ),
                        ),
                      ),
                      const SizedBox(height: PicPacSpacing.xs),
                      Text(
                        l10n.paymentAmountDue(fmt.money(amount)),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: PicPacColors.accentText,
                        ),
                      ),
                      const SizedBox(height: PicPacSpacing.md),
                      if (choosing) ...<Widget>[
                        _RegionSwitch(
                          region: state.region,
                          onChanged: (region) =>
                              _controller.selectRegion(region),
                        ),
                        const SizedBox(height: PicPacSpacing.md),
                        if (state.loadingMethods)
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              SkeletonBox(height: 56),
                              SizedBox(height: PicPacSpacing.sm),
                              SkeletonBox(height: 56),
                            ],
                          )
                        else if (state.methodsFailure != null)
                          _InlineError(
                            text: paymentFailureText(
                              l10n,
                              state.methodsFailure!,
                            ),
                            onRetry: () => _controller.loadMethods(force: true),
                          )
                        else if (state.methods.isEmpty)
                          Text(
                            l10n.paymentNoMethods,
                            style: theme.textTheme.bodyMedium,
                          )
                        else
                          Column(
                            key: const Key('payment-methods'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              for (final method in state.methods) ...<Widget>[
                                _MethodTile(
                                  method: method,
                                  selected: method.id == state.selected?.id,
                                  onTap: () => _controller.select(method),
                                ),
                                const SizedBox(height: PicPacSpacing.sm),
                              ],
                            ],
                          ),
                        if (flow.failure != null && intent == null) ...<Widget>[
                          const SizedBox(height: PicPacSpacing.sm),
                          Text(
                            paymentFailureText(l10n, flow.failure!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: PicPacColors.accentText,
                            ),
                          ),
                        ],
                      ] else
                        _StatusSection(
                          state: state,
                          intent: intent,
                          orderTotal: widget.order.totals.total,
                          resultFocus: _resultFocus,
                          onCheckAgain: () async {
                            await _controller.pollNow();
                            await _controller.startPolling();
                          },
                        ),
                    ],
                  ),
                ),
                _ActionBar(
                  state: state,
                  choosing: choosing,
                  onPay: _controller.pay,
                  onRetry: _controller.retry,
                  onReceipt: _openReceipt,
                  onOpenPage: () async {
                    final opened = await _controller.openHostedPage();
                    if (opened) await _controller.startPolling();
                  },
                  onCheckAgain: () async {
                    await _controller.pollNow();
                    await _controller.startPolling();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RegionSwitch extends StatelessWidget {
  const _RegionSwitch({required this.region, required this.onChanged});

  final String region;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.paymentRegionLabel,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: FunnelText.secondary),
        ),
        const SizedBox(height: PicPacSpacing.xs),
        SegmentedButton<String>(
          key: const Key('payment-region'),
          segments: <ButtonSegment<String>>[
            ButtonSegment<String>(
              value: 'BY',
              label: Text(l10n.paymentRegionBy),
            ),
            ButtonSegment<String>(
              value: 'RU',
              label: Text(l10n.paymentRegionRu),
            ),
          ],
          selected: <String>{region},
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            if (selection.isEmpty) return;
            onChanged(selection.first);
          },
        ),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hint = paymentMethodHint(l10n, method);
    return Semantics(
      selected: selected,
      button: true,
      label: paymentMethodLabel(l10n, method),
      child: Material(
        color: selected ? PicPacColors.accentSoft : PicPacColors.surface,
        borderRadius: BorderRadius.circular(PicPacRadii.field),
        child: InkWell(
          key: Key('payment-method-${method.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(PicPacRadii.field),
          child: Ink(
            padding: const EdgeInsets.all(PicPacSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PicPacRadii.field),
              border: Border.all(
                color: selected ? PicPacColors.accent : PicPacColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: kMinTouchTarget),
              child: Row(
                children: <Widget>[
                  Icon(method.icon, size: 22, color: PicPacColors.ink),
                  const SizedBox(width: PicPacSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          paymentMethodLabel(l10n, method),
                          style: theme.textTheme.titleSmall,
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
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.check_circle,
                      size: 20,
                      color: PicPacColors.inkStrong,
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

class _StatusSection extends StatelessWidget {
  const _StatusSection({
    required this.state,
    required this.intent,
    required this.onCheckAgain,
    required this.orderTotal,
    required this.resultFocus,
  });

  final PaymentState state;
  final PaymentIntent? intent;
  final Future<void> Function() onCheckAgain;

  final Money orderTotal;

  final FocusNode resultFocus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fmt = Fmt.of(context);
    final flow = state.flow;
    final hosted = intent?.hostedPageUrl;
    final hostedFailed =
        flow.failure?.code == PaymentErrorCode.hostedPageFailed;

    Widget chip(String label, ChipTone tone) => Align(
      alignment: Alignment.centerLeft,
      child: StatusChip(label: label, tone: tone, liveRegion: true),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (flow.phase == PaymentPhase.succeeded)
          _PaidHero(
            focusNode: resultFocus,
            amount: fmt.money(intent?.amount ?? orderTotal),
          )
        else
          Focus(
            focusNode: resultFocus,
            skipTraversal: true,
            child: switch (flow.phase) {
              PaymentPhase.failed => chip(l10n.paymentFailed, ChipTone.danger),
              PaymentPhase.expired => chip(
                l10n.paymentExpired,
                ChipTone.warning,
              ),
              PaymentPhase.canceled => chip(
                l10n.paymentCanceled,
                ChipTone.neutral,
              ),
              PaymentPhase.onDelivery => chip(
                l10n.paymentOnDelivery,
                ChipTone.neutral,
              ),
              _ => chip(
                paymentStatusLabel(l10n, intent?.status),
                flow.uncertain ? ChipTone.warning : ChipTone.progress,
              ),
            },
          ),
        const SizedBox(height: PicPacSpacing.md),
        if (flow.phase.isWaiting)
          Semantics(
            liveRegion: true,
            child: Row(
              children: <Widget>[
                _Spinner(active: !state.pollTimedOut && !hostedFailed),
                const SizedBox(width: PicPacSpacing.sm),
                Expanded(
                  child: Text(
                    hostedFailed
                        ? l10n.paymentHostedPageFailed
                        : state.pollTimedOut
                        ? l10n.paymentCheckFailed
                        : flow.uncertain
                        ? l10n.paymentUncertain
                        : l10n.paymentChecking,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        if (flow.phase.isWaiting &&
            hosted != null &&
            !state.pollTimedOut &&
            !hostedFailed)
          Padding(
            padding: const EdgeInsets.only(top: PicPacSpacing.sm),
            child: Text(
              l10n.paymentAwaitingUser,
              style: theme.textTheme.bodySmall?.copyWith(
                color: FunnelText.secondary,
              ),
            ),
          ),
        if (state.pollTimedOut) ...<Widget>[
          const SizedBox(height: PicPacSpacing.sm),
          OutlinedButton(
            key: const Key('payment-check-again'),
            onPressed: () => onCheckAgain(),
            child: Text(l10n.paymentCheckAgain),
          ),
        ],
        if (flow.failure != null && !flow.phase.isWaiting) ...<Widget>[
          const SizedBox(height: PicPacSpacing.sm),
          Text(
            paymentFailureText(l10n, flow.failure!),
            style: theme.textTheme.bodySmall?.copyWith(
              color: PicPacColors.accentText,
            ),
          ),
        ],
      ],
    );
  }
}

class _PaidHero extends StatelessWidget {
  const _PaidHero({required this.focusNode, required this.amount});

  final FocusNode focusNode;

  final String amount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Focus(
      focusNode: focusNode,
      skipTraversal: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.check_circle, size: 32, color: PicPacColors.accent),
          const SizedBox(height: PicPacSpacing.sm),
          Semantics(
            header: true,
            child: Text(l10n.paymentPaid, style: theme.textTheme.displayLarge),
          ),
          const SizedBox(height: PicPacSpacing.xs),
          Text(amount, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    if (!active || MediaQuery.disableAnimationsOf(context)) {
      return const Icon(
        Icons.hourglass_empty,
        size: 18,
        color: PicPacColors.ink,
      );
    }
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: PicPacColors.accentText),
        ),
        const SizedBox(height: PicPacSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: onRetry,
            child: Text(l10n.actionRetry),
          ),
        ),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.state,
    required this.choosing,
    required this.onPay,
    required this.onRetry,
    required this.onReceipt,
    required this.onOpenPage,
    required this.onCheckAgain,
  });

  final PaymentState state;
  final bool choosing;
  final Future<void> Function() onPay;
  final Future<void> Function() onRetry;
  final Future<void> Function() onReceipt;
  final Future<void> Function() onOpenPage;
  final Future<void> Function() onCheckAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final flow = state.flow;
    final hosted = flow.intent?.hostedPageUrl;
    final failure = flow.failure;
    final Widget action;
    if (choosing) {
      action = FilledButton(
        key: const Key('payment-pay'),
        onPressed: state.canPay ? () => onPay() : null,
        child: Text(state.creating ? l10n.paymentPreparing : l10n.paymentPay),
      );
    } else {
      switch (flow.phase) {
        case PaymentPhase.succeeded:
          action = FilledButton.icon(
            key: const Key('payment-receipt'),
            onPressed: () => onReceipt(),
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: Text(
              state.loadingReceipt ? l10n.loading : l10n.paymentReceipt,
            ),
          );
        case PaymentPhase.failed:
        case PaymentPhase.expired:
        case PaymentPhase.canceled:
          action = FilledButton(
            key: const Key('payment-retry'),
            onPressed: state.creating ? null : () => onRetry(),
            child: Text(
              flow.phase == PaymentPhase.failed
                  ? l10n.paymentRetry
                  : l10n.paymentCreateNew,
            ),
          );
        case PaymentPhase.onDelivery:
          action = Text(
            l10n.paymentOnDeliveryHint,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: FunnelText.secondary),
          );
        case PaymentPhase.awaitingUser
            when failure?.code == PaymentErrorCode.hostedPageFailed:
          action = FilledButton.icon(
            key: const Key('payment-open-page'),
            onPressed: () => onOpenPage(),
            icon: const Icon(Icons.open_in_browser, size: 18),
            label: Text(l10n.paymentHostedPageAgain),
          );
        case PaymentPhase.awaitingUser || PaymentPhase.polling:
          action = Text(
            hosted == null ? l10n.paymentChecking : l10n.paymentAwaitingUser,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: FunnelText.secondary),
          );
        case PaymentPhase.idle:
        case PaymentPhase.preparing:
          action = FilledButton(
            key: const Key('payment-pay'),
            onPressed: state.canPay ? () => onPay() : null,
            child: Text(l10n.paymentPreparing),
          );
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PicPacSpacing.lg,
        PicPacSpacing.sm,
        PicPacSpacing.lg,
        PicPacSpacing.md,
      ),
      child: MinTapTarget(
        child: Align(
          alignment: Alignment.center,
          heightFactor: 1,
          child: action,
        ),
      ),
    );
  }
}
