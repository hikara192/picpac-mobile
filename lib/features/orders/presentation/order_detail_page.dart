import 'dart:async';

import 'package:api_contract/api_contract.dart' hide TextAlign;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../app/env.dart';
import '../../../app/router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/analytics.dart';
import '../../../core/orders/demo_controls.dart';
import '../../../core/session/session_controller.dart';
import '../../../payments/payment_flow.dart';
import '../../../payments/presentation/payment_sheet.dart';
import '../../../core/orders/orders_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../_shared/application/async_retry.dart';
import '../../../core/presentation/a11y.dart';
import '../../../core/presentation/failure_text.dart';
import '../../../core/presentation/format.dart';
import '../../../core/presentation/text_tones.dart';
import '../../../core/presentation/state_views.dart';
import '../application/orders_controller.dart';
import 'widgets/order_status_labels.dart';

class OrderDetailPage extends ConsumerStatefulWidget {
  const OrderDetailPage({required this.orderId, this.initialOrder, super.key});

  final String orderId;

  final Order? initialOrder;

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage>
    with WidgetsBindingObserver {
  Order? _demoOrder;

  PaymentStatus? _paymentStatus;

  bool _demoUnavailable = false;

  bool _advanceNeedsSupport = false;

  bool _paymentUnavailable = false;

  bool _demoBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final seed = widget.initialOrder;
    if (seed != null) {
      ref.read(analyticsProvider).track(
        AnalyticsEvent.orderOpened,
        <String, Object?>{'orderId': seed.id, 'seeded': true},
      );
      unawaited(ref.read(ordersRepositoryProvider).remember(seed));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    ref.invalidate(orderDetailProvider(widget.orderId));
    final order = _demoOrder ?? widget.initialOrder;
    if (order != null && !order.paymentStatus.isPaid) {
      unawaited(_verifyPayment(order));
    }
  }

  bool get _demoEnabled {
    final environment = ref.read(envProvider);
    if (environment.flavor != AppFlavor.dev) return false;
    if (!kDebugMode &&
        !const bool.fromEnvironment('DEMO_CONTROLS', defaultValue: true)) {
      return false;
    }
    final session = ref.watch(sessionControllerProvider);
    if (!session.isSupportAgent && !session.isAccount) return false;
    final env = ref.read(envProvider);
    if (env.flavor != AppFlavor.dev) return false;
    if (env.apiMode != ApiMode.embedded && env.apiMode != ApiMode.http) {
      return false;
    }
    return !_demoUnavailable && ref.read(demoOrderControlsProvider) != null;
  }

  Order _orderFor(Order source) => _demoOrder ?? source;

  Future<void> _verifyPayment(Order order) async {
    final refreshed = await ref.read(apiPortProvider).order(order.id);
    if (!mounted) return;
    if (refreshed case Ok<Order>(:final value)) {
      setState(() {
        _demoOrder = value;
        _paymentStatus = value.paymentStatus;
      });
    }
  }

  Future<void> _advance(Order order, {String? to}) async {
    final controls = ref.read(demoOrderControlsProvider);
    if (controls == null) return;
    setState(() => _demoBusy = true);
    final result = await controls.advance(order.id, to: to);
    if (!mounted) return;
    Order? advanced;
    setState(() {
      _demoBusy = false;
      switch (result) {
        case Ok<Order>(:final value):
          _demoOrder = value;
          _paymentStatus = value.paymentStatus;
          advanced = value;
        case Err<Order>(:final error):
          if (isAdvanceNeedsSupport(error)) {
            _advanceNeedsSupport = true;
          } else if (isDemoEndpointUnavailable(error)) {
            _demoUnavailable = true;
          }
      }
    });
    if (!mounted) return;
    switch (result) {
      case Err<Order>(:final error):
        _reportDemoFailure(error);
      case Ok<Order>():
        final l10n = AppLocalizations.of(context);
        final updated = advanced;
        final paidNow =
            updated != null &&
            updated.paymentStatus.isPaid &&
            !order.paymentStatus.isPaid;
        announceToScreenReader(
          context,
          paidNow
              ? '${l10n.orderPaymentTitle}: '
                    '${paymentStatusLabel(l10n, updated.paymentStatus)}'
              : '${l10n.orderFulfillmentTitle}: '
                    '${orderStatusLabel(l10n, updated?.fulfillmentStatus ?? order.fulfillmentStatus)}',
        );
    }
  }

  Future<void> _payDemo(Order order) async {
    final controls = ref.read(demoOrderControlsProvider);
    if (controls == null) return;
    final api = ref.read(apiPortProvider);
    setState(() => _demoBusy = true);
    try {
      final catalog = await api.catalog();
      final region = catalog.valueOrNull?.region ?? 'BY';
      final methods = await api.paymentMethods(region: region);
      PaymentMethodInfo? method;
      for (final candidate
          in methods.valueOrNull ?? const <PaymentMethodInfo>[]) {
        if (!candidate.enabled) continue;
        if (candidate.kind == 'card') {
          method = candidate;
          break;
        }
        method ??= candidate;
      }
      if (method == null) {
        if (mounted) setState(() => _demoBusy = false);
        _reportDemoFailure(
          const ApiFailure(
            code: ApiErrorCode.notFound,
            message: 'no enabled payment method in the region',
          ),
        );
        return;
      }
      final intent = await api.createPaymentIntent(
        CreatePaymentIntentRequest(
          orderId: order.id,
          methodId: method.id,
          region: region,
        ),
        idempotencyKey: 'demo-payment-${order.id}',
      );
      final created = intent.valueOrNull;
      if (created == null) {
        if (mounted) setState(() => _demoBusy = false);
        _reportDemoFailure(
          intent.failureOrNull ??
              const ApiFailure(
                code: ApiErrorCode.serverError,
                message: 'the intent was not created',
              ),
        );
        return;
      }
      PaymentStatus? settled;
      final hosted = created.hostedPageUrl;
      if (hosted != null) {
        final confirmed = await controls.confirmHostedPayment(
          Uri.parse(hosted),
        );
        if (confirmed case Err<void>(:final error)) {
          if (!mounted) return;
          setState(() {
            _demoBusy = false;
            if (isDemoEndpointUnavailable(error)) _paymentUnavailable = true;
          });
          _reportDemoFailure(error);
          return;
        }
      } else {
        final simulated = await controls.simulateCardSuccess(orderId: order.id);
        if (simulated case Err<PaymentIntent>(:final error)) {
          if (!mounted) return;
          setState(() {
            _demoBusy = false;
            if (isDemoEndpointUnavailable(error)) _paymentUnavailable = true;
          });
          _reportDemoFailure(error);
          return;
        }
        settled = simulated.valueOrNull?.status;
      }
      final verified = await api.paymentIntent(created.id);
      final status = verified.valueOrNull?.status ?? settled;
      final refreshed = await api.order(order.id);
      if (!mounted) return;
      setState(() {
        _demoBusy = false;
        if (status != null) _paymentStatus = status;
        if (refreshed case Ok<Order>(:final value)) _demoOrder = value;
      });
    } finally {
      if (mounted && _demoBusy) setState(() => _demoBusy = false);
    }
  }

  void _reportDemoFailure(Failure failure) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.orderDemoFailed}: ${failureText(l10n, failure)}',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final seed = widget.initialOrder;
    if (seed != null) {
      final pointId = seed.delivery.pointId;
      final optionId = seed.delivery.optionId;
      final order = _orderFor(seed);
      return Scaffold(
        appBar: AppBar(title: Text(l10n.orderTitle)),
        body: _OrderBody(
          order: order,
          pickupPoint: pointId == null
              ? null
              : ref.watch(pickupPointProvider(pointId)).value,
          deliveryOption: optionId == null
              ? null
              : ref.watch(deliveryOptionProvider(optionId)).value,
          paymentStatus: _paymentStatus,
          demo: _demoCard(order),
          onPay: () async {
            await showPaymentSheet(context, order: order);
            if (!mounted) return;
            ref.invalidate(orderDetailProvider(order.id));
            await _verifyPayment(_demoOrder ?? order);
          },
          onPush: _demoEnabled ? () => _demoPush(order) : null,
        ),
      );
    }
    final detail = ref.watch(orderDetailProvider(widget.orderId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.orderTitle)),
      body: switch (detail) {
        AsyncData<OrderDetailView>(:final value) => _OrderBody(
          order: _orderFor(value.snapshot.order),
          pickupPoint: value.pickupPoint,
          deliveryOption: value.deliveryOption,
          stale: value.snapshot.stale,
          paymentStatus: _paymentStatus,
          demo: _demoCard(_orderFor(value.snapshot.order)),
          onPay: () =>
              showPaymentSheet(context, order: _orderFor(value.snapshot.order)),
        ),
        AsyncError<OrderDetailView>(:final error) => FailureView(
          failure: failureOr(error),
          title: l10n.orderNotFound,
          onRetry: () => ref.invalidate(orderDetailProvider(widget.orderId)),
          onLogin: () => context.push(AppRoutes.login),
        ),
        _ => const CardListSkeleton(),
      },
    );
  }

  Future<void> _demoPush(Order order) async {
    await _advance(order);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final current = _demoOrder ?? order;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Row(
            children: <Widget>[
              const Icon(Icons.notifications_active_outlined, size: 20),
              const SizedBox(width: PicPacSpacing.sm),
              Expanded(
                child: Text(
                  l10n.orderDemoPushBody(
                    order.number,
                    orderStatusLabel(l10n, current.fulfillmentStatus),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget? _demoCard(Order order) {
    if (!_demoEnabled) return null;
    return _DemoCard(
      order: order,
      busy: _demoBusy,
      paymentStatus: _paymentStatus,
      advanceNeedsSupport: _advanceNeedsSupport,
      paymentUnavailable: _paymentUnavailable,
      onAdvance: () => _advance(order),
      onCancel: () => _advance(order, to: 'canceled'),
      onPay: () => _payDemo(order),
      onPush: () => _demoPush(order),
    );
  }
}

class _OrderBody extends StatelessWidget {
  const _OrderBody({
    required this.order,
    this.pickupPoint,
    this.deliveryOption,
    this.stale = false,
    this.paymentStatus,
    this.demo,
    this.onPay,
    this.onPush,
  });

  final Order order;
  final PickupPoint? pickupPoint;
  final DeliveryOption? deliveryOption;
  final bool stale;

  final PaymentStatus? paymentStatus;

  final Widget? demo;

  final VoidCallback? onPay;

  final VoidCallback? onPush;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fmt = Fmt.of(context);
    final delivery = order.delivery;
    final eta = order.eta;
    final payment = paymentStatus ?? order.paymentStatus;
    final kindLabel = deliveryKindLabel(l10n, delivery.kind);
    final optionLabel = deliveryOption == null
        ? null
        : deliveryOptionLabel(l10n, deliveryOption!.titleKey);
    final optionHint = optionLabel != null && optionLabel != kindLabel
        ? optionLabel
        : null;
    return ListView(
      padding: const EdgeInsets.all(PicPacSpacing.lg),
      children: <Widget>[
        if (stale) ...<Widget>[
          _Banner(icon: Icons.history, text: l10n.ordersStale),
          const SizedBox(height: PicPacSpacing.md),
        ],
        Semantics(
          header: true,
          child: Text(
            l10n.orderHeading(order.number),
            style: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: PicPacSpacing.xs),
        Text(
          l10n.orderCreatedAt(fmt.dateTime(order.createdAt)),
          style: theme.textTheme.bodySmall?.copyWith(
            color: FunnelText.secondary,
          ),
        ),
        if (eta != null) ...<Widget>[
          const SizedBox(height: PicPacSpacing.xxs),
          Text(
            l10n.orderEta(fmt.date(eta)),
            style: theme.textTheme.bodySmall?.copyWith(
              color: FunnelText.secondary,
            ),
          ),
        ],
        const SizedBox(height: PicPacSpacing.lg),
        SectionCard(
          child: Column(
            children: <Widget>[
              _StatusRow(
                label: l10n.orderPaymentTitle,
                chip: StatusChip(
                  label: paymentStatusLabel(l10n, payment),
                  tone: paymentStatusTone(order.paymentStatus),
                  liveRegion: true,
                ),
              ),
              const Divider(height: PicPacSpacing.xl),
              _StatusRow(
                label: l10n.orderFulfillmentTitle,
                chip: StatusChip(
                  label: orderStatusLabel(l10n, order.fulfillmentStatus),
                  tone: orderStatusTone(order.fulfillmentStatus),
                  liveRegion: true,
                ),
              ),
            ],
          ),
        ),
        if (onPush != null)
          Padding(
            padding: const EdgeInsets.only(top: PicPacSpacing.md),
            child: OutlinedButton.icon(
              onPressed: onPush,
              icon: const Icon(Icons.notifications_active_outlined, size: 18),
              label: Text(l10n.orderDemoPush),
            ),
          ),
        if (onPay != null &&
            paymentCallToAction(order) == PaymentCallToAction.pay)
          Padding(
            padding: const EdgeInsets.only(top: PicPacSpacing.md),
            child: FilledButton.icon(
              onPressed: onPay,
              icon: const Icon(Icons.credit_card, size: 20),
              label: Text(l10n.orderPayCta),
            ),
          ),
        if (delivery.pickupCode != null) ...<Widget>[
          const SizedBox(height: PicPacSpacing.md),
          SectionCard(
            title: l10n.orderPickupCode,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SelectableText(
                  delivery.pickupCode!,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    letterSpacing: 8,
                    color: PicPacColors.accentText,
                  ),
                ),
                const SizedBox(height: PicPacSpacing.xs),
                Text(
                  l10n.orderPickupCodeHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: FunnelText.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: PicPacSpacing.md),
        SectionCard(
          title: l10n.orderDeliveryTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(kindLabel, style: theme.textTheme.bodyMedium),
                  ),
                  if (optionHint != null)
                    Text(
                      optionHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: FunnelText.secondary,
                      ),
                    ),
                ],
              ),
              if (pickupPoint != null) ...<Widget>[
                const SizedBox(height: PicPacSpacing.xs),
                Text(
                  '${pickupPoint!.city}, ${pickupPoint!.address}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: FunnelText.secondary,
                  ),
                ),
              ],
              if (delivery.address != null) ...<Widget>[
                const SizedBox(height: PicPacSpacing.xs),
                Text(
                  delivery.address!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: FunnelText.secondary,
                  ),
                ),
              ],
              if (delivery.slot != null) ...<Widget>[
                const SizedBox(height: PicPacSpacing.xs),
                Text(
                  fmt.dateTime(delivery.slot!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: FunnelText.secondary,
                  ),
                ),
              ],
              if (order.trackingNumber != null) ...<Widget>[
                const SizedBox(height: PicPacSpacing.xs),
                Text(
                  l10n.orderTracking(order.trackingNumber!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: FunnelText.secondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: PicPacSpacing.md),
        SectionCard(
          title: l10n.orderItemsTitle,
          child: Column(
            children: <Widget>[
              for (final item in order.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: PicPacSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.productTitle,
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: PicPacSpacing.xxs),
                            Text(
                              l10n.orderItemQuantity(
                                item.quantity,
                                fmt.money(item.unitPrice),
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: FunnelText.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: PicPacSpacing.md),
                      Flexible(
                        child: Text(
                          fmt.money(item.total),
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: PicPacSpacing.md),
        SectionCard(
          title: l10n.orderTotalsTitle,
          child: Column(
            children: <Widget>[
              _TotalRow(
                label: l10n.orderSubtotal,
                value: fmt.money(order.totals.subtotal),
              ),
              if (!order.totals.discount.isZero)
                _TotalRow(
                  label: l10n.orderDiscount,
                  value: fmt.money(order.totals.discount),
                ),
              _TotalRow(
                label: l10n.orderDeliveryCost,
                value: fmt.money(order.totals.delivery),
              ),
              const Divider(height: PicPacSpacing.xl),
              _TotalRow(
                label: l10n.orderTotal,
                value: fmt.money(order.totals.total),
                emphasized: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: PicPacSpacing.md),
        SectionCard(
          title: l10n.orderTimelineTitle,
          child: Column(
            children: <Widget>[
              for (var i = 0; i < order.history.length; i++)
                _TimelineRow(
                  event: order.history[i],
                  last: i == order.history.length - 1,
                ),
            ],
          ),
        ),
        if (demo != null) ...<Widget>[
          const SizedBox(height: PicPacSpacing.md),
          demo!,
        ],
        const SizedBox(height: PicPacSpacing.lg),
        OutlinedButton(
          onPressed: () => context.push(AppRoutes.support),
          child: Text(l10n.orderProblem),
        ),
        const SizedBox(height: PicPacSpacing.lg),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.chip});

  final String label;
  final Widget chip;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ),
      const SizedBox(width: PicPacSpacing.sm),
      Flexible(child: chip),
    ],
  );
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = emphasized
        ? theme.textTheme.headlineSmall?.copyWith(
            color: PicPacColors.accent,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          )
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PicPacSpacing.xxs),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: PicPacSpacing.sm),
          Flexible(
            child: Text(value, textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.last});

  final OrderStatusEvent event;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fmt = Fmt.of(context);
    final tone = orderStatusTone(event.status);
    final color = switch (tone) {
      ChipTone.success => PicPacColors.inkStrong,
      ChipTone.danger => PicPacColors.accentText,
      _ => PicPacColors.muted,
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: PicPacSpacing.xxs),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              if (!last)
                Expanded(
                  child: Container(width: 1, color: PicPacColors.border),
                ),
            ],
          ),
          const SizedBox(width: PicPacSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : PicPacSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    orderStatusLabel(l10n, event.status),
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    fmt.dateTime(event.at),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: FunnelText.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(PicPacSpacing.md),
      decoration: BoxDecoration(
        color: PicPacColors.fillBeige,
        borderRadius: BorderRadius.circular(PicPacRadii.field),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: PicPacColors.ink),
          const SizedBox(width: PicPacSpacing.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    ),
  );
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({
    required this.order,
    required this.busy,
    required this.paymentStatus,
    required this.advanceNeedsSupport,
    required this.paymentUnavailable,
    required this.onAdvance,
    required this.onCancel,
    required this.onPay,
    required this.onPush,
  });

  final Order order;
  final bool busy;
  final PaymentStatus? paymentStatus;
  final bool advanceNeedsSupport;
  final bool paymentUnavailable;
  final VoidCallback onAdvance;
  final VoidCallback onCancel;
  final VoidCallback onPay;
  final VoidCallback onPush;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final paid = (paymentStatus ?? order.paymentStatus).isPaid;
    return SectionCard(
      title: l10n.orderDemoTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Tooltip(
            message: l10n.orderDemoTooltip,
            child: Text(
              l10n.orderDemoHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: FunnelText.secondary,
              ),
            ),
          ),
          const SizedBox(height: PicPacSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: MinTapTarget(
                  child: OutlinedButton.icon(
                    key: const Key('order-demo-advance'),
                    onPressed: busy
                        ? null
                        : advanceNeedsSupport
                        ? onCancel
                        : onAdvance,
                    icon: Icon(
                      advanceNeedsSupport
                          ? Icons.cancel_outlined
                          : Icons.fast_forward_outlined,
                      size: 18,
                    ),
                    label: Text(
                      advanceNeedsSupport
                          ? l10n.orderDemoCancel
                          : l10n.orderDemoAdvance,
                    ),
                  ),
                ),
              ),
              if (!paid && !paymentUnavailable) ...<Widget>[
                const SizedBox(width: PicPacSpacing.sm),
                Expanded(
                  child: MinTapTarget(
                    child: FilledButton.icon(
                      key: const Key('order-demo-pay'),
                      onPressed: busy ? null : onPay,
                      icon: const Icon(Icons.credit_card, size: 18),
                      label: Text(l10n.orderDemoPay),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (advanceNeedsSupport) ...<Widget>[
            const SizedBox(height: PicPacSpacing.xxs),
            Text(
              l10n.orderDemoNeedsSupport,
              style: theme.textTheme.bodySmall?.copyWith(
                color: FunnelText.secondary,
              ),
            ),
          ],
          if (paid) ...<Widget>[
            const SizedBox(height: PicPacSpacing.xxs),
            Text(
              l10n.orderDemoPaid,
              style: theme.textTheme.bodySmall?.copyWith(
                color: PicPacColors.inkStrong,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
