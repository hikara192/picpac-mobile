import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/orders/orders_repository.dart';
import '../../../core/session/session_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../_shared/application/async_retry.dart';
import '../../../core/presentation/a11y.dart';
import '../../../core/presentation/failure_text.dart';
import '../../../core/presentation/format.dart';
import '../../../core/presentation/text_tones.dart';
import '../../../core/presentation/state_views.dart';
import '../application/orders_controller.dart';
import 'widgets/order_status_labels.dart';

class OrdersPage extends ConsumerWidget {
  const OrdersPage({this.lookupMode = false, super.key});

  final bool lookupMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (lookupMode) return const _OrderLookupPage();
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ordersTitle, style: AppTheme.rootTabTitle),
        actions: <Widget>[
          IconButton(
            key: const Key('orders-open-projects'),
            tooltip: l10n.projectsTitle,
            onPressed: () => context.push(AppRoutes.projects),
            icon: const Icon(Icons.photo_album_outlined),
          ),
          IconButton(
            tooltip: l10n.ordersLookup,
            onPressed: () => context.push(AppRoutes.orderLookup),
            icon: const Icon(Icons.search),
          ),
          const SizedBox(width: PicPacSpacing.xs),
        ],
      ),
      body: const _OrderHistory(),
    );
  }
}

class _OrderHistory extends ConsumerWidget {
  const _OrderHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final role = ref.watch(sessionServiceProvider).role;
    final canSeeHistory =
        role == UserRole.customer || role == UserRole.supportAgent;
    if (!canSeeHistory) {
      return EmptyView(
        title: l10n.ordersTitle,
        body: l10n.ordersLoginRequired,
        icon: Icons.receipt_long_outlined,
        action: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FilledButton(
              onPressed: () => context.push(AppRoutes.login),
              child: Text(l10n.actionLogin),
            ),
            const SizedBox(height: PicPacSpacing.sm),
            OutlinedButton(
              onPressed: () => context.push(AppRoutes.orderLookup),
              child: Text(l10n.ordersLookup),
            ),
          ],
        ),
      );
    }
    final history = ref.watch(ordersProvider);
    return switch (history) {
      AsyncData<OrderHistorySnapshot>(:final value) =>
        value.orders.isEmpty
            ? EmptyView(
                title: l10n.ordersEmptyTitle,
                body: l10n.ordersEmptyBody,
                icon: Icons.receipt_long_outlined,
                action: FilledButton(
                  onPressed: () => context.go(AppRoutes.catalog),
                  child: Text(l10n.actionGoCatalog),
                ),
              )
            : RefreshIndicator(
                color: PicPacColors.accent,
                onRefresh: () async {
                  await ref.read(ordersProvider.notifier).reload();
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(PicPacSpacing.lg),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: value.orders.length + (value.stale ? 1 : 0) + 1,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: PicPacSpacing.md),
                  itemBuilder: (context, index) {
                    var cursor = index;
                    if (value.stale) {
                      if (cursor == 0) return const _StaleBanner();
                      cursor -= 1;
                    }
                    if (cursor == value.orders.length) {
                      return value.hasMore
                          ? Center(
                              child: TextButton(
                                onPressed: () => ref
                                    .read(ordersProvider.notifier)
                                    .loadMore(),
                                child: Text(l10n.actionLoadMore),
                              ),
                            )
                          : const SizedBox.shrink();
                    }
                    return _OrderCard(order: value.orders[cursor]);
                  },
                ),
              ),
      AsyncError<OrderHistorySnapshot>(:final error) => FailureView(
        failure: failureOr(error),
        onRetry: () => ref.invalidate(ordersProvider),
        onLogin: () => context.push(AppRoutes.login),
      ),
      _ => const CardListSkeleton(),
    };
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(PicPacSpacing.md),
        decoration: BoxDecoration(
          color: PicPacColors.fillBeige,
          borderRadius: BorderRadius.circular(PicPacRadii.field),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.history, size: 20, color: PicPacColors.ink),
            const SizedBox(width: PicPacSpacing.sm),
            Expanded(
              child: Text(
                l10n.ordersStale,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fmt = Fmt.of(context);
    final status = order.fulfillmentStatus;
    return Semantics(
      container: true,
      button: true,
      label: a11yOrderCardLabel(
        l10n,
        number: order.number,
        status: orderStatusLabel(l10n, order.fulfillmentStatus),
        total: fmt.money(order.totals.total),
      ),
      excludeSemantics: true,
      onTap: () => context.push(AppRoutes.orderFor(order.id), extra: order),
      child: Material(
        color: PicPacColors.surface,
        borderRadius: BorderRadius.circular(PicPacRadii.card),
        child: InkWell(
          onTap: () => context.push(AppRoutes.orderFor(order.id), extra: order),
          borderRadius: BorderRadius.circular(PicPacRadii.card),
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
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        order.number,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    StatusChip(
                      label: orderStatusLabel(l10n, status),
                      tone: orderStatusTone(status),
                    ),
                  ],
                ),
                const SizedBox(height: PicPacSpacing.xs),
                Text(
                  fmt.dateTime(order.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: FunnelText.secondary,
                  ),
                ),
                const SizedBox(height: PicPacSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l10n.ordersItemsCount(order.items.length),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: FunnelText.secondary,
                        ),
                      ),
                    ),
                    Text(
                      fmt.money(order.totals.total),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: PicPacColors.accentText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderLookupPage extends ConsumerStatefulWidget {
  const _OrderLookupPage();

  @override
  ConsumerState<_OrderLookupPage> createState() => _OrderLookupPageState();
}

class _OrderLookupPageState extends ConsumerState<_OrderLookupPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _number = TextEditingController();
  final TextEditingController _last4 = TextEditingController();
  bool _busy = false;
  Failure? _failure;

  @override
  void dispose() {
    _number.dispose();
    _last4.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final result = await ref
        .read(ordersRepositoryProvider)
        .lookup(number: _number.text.trim(), phoneLast4: _last4.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Ok<Order>(:final value):
        context.push(AppRoutes.orderFor(value.id), extra: value);
      case Err<Order>(:final error):
        setState(() => _failure = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.lookupTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(PicPacSpacing.lg),
          children: <Widget>[
            Text(l10n.lookupBody, style: theme.textTheme.bodyMedium),
            const SizedBox(height: PicPacSpacing.lg),
            TextFormField(
              controller: _number,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l10n.lookupNumber),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? l10n.errorValidation : null,
            ),
            const SizedBox(height: PicPacSpacing.md),
            TextFormField(
              controller: _last4,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _lookup(),
              decoration: InputDecoration(
                labelText: l10n.lookupPhoneLast4,
                counterText: '',
              ),
              validator: (value) => (value ?? '').trim().length == 4
                  ? null
                  : l10n.lookupPhoneLast4Invalid,
            ),
            if (_failure != null) ...<Widget>[
              const SizedBox(height: PicPacSpacing.md),
              Text(
                _lookupFailureText(_failure!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: PicPacColors.accentText,
                ),
              ),
            ],
            const SizedBox(height: PicPacSpacing.xl),
            FilledButton(
              onPressed: _busy ? null : _lookup,
              child: Text(_busy ? l10n.loading : l10n.actionFind),
            ),
          ],
        ),
      ),
    );
  }

  String _lookupFailureText(Failure failure) {
    final l10n = AppLocalizations.of(context);
    if (failure.code == ApiErrorCode.notFound) return l10n.lookupNotFound;
    if (failure.code == ApiErrorCode.rateLimited) return l10n.errorRateLimited;
    return failureText(l10n, failure);
  }
}
