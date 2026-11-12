import 'package:api_contract/api_contract.dart' hide TextAlign;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../app/router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/session/guest_work.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/session/session_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../_shared/application/async_retry.dart';
import '../../../core/presentation/a11y.dart';
import '../../../core/presentation/failure_text.dart';
import '../../../core/presentation/format.dart';
import '../../_shared/presentation/product_artwork.dart';
import '../../../core/presentation/state_views.dart';
import '../../../core/presentation/text_tones.dart';
import '../application/cart_controller.dart';

class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cart = ref.watch(cartProvider);
    return Scaffold(
      appBar: AppBar(
        leading: context.canPop()
            ? const BackButton()
            : IconButton(
                key: const Key('cart-close'),
                tooltip: l10n.actionGoCatalog,
                onPressed: () => context.go(AppRoutes.catalog),
                icon: const Icon(Icons.close),
              ),
        title: Text(l10n.cartTitle),
      ),
      body: switch (cart) {
        AsyncData<CartView>(:final value) => _CartBody(view: value),
        AsyncError<CartView>(:final error) => FailureView(
          failure: failureOr(error),
          onRetry: () => ref.invalidate(cartProvider),
          onLogin: () => context.push(AppRoutes.loginFor(AppRoutes.cart)),
        ),
        _ => const CardListSkeleton(),
      },
      bottomNavigationBar: switch (cart) {
        AsyncData<CartView>(:final value) when value.lines.isNotEmpty =>
          _CartSummary(view: value),
        _ => null,
      },
    );
  }
}

class _CartBody extends ConsumerWidget {
  const _CartBody({required this.view});

  final CartView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final expiresAt = view.context.cart.expiresAt;
    final expired = expiresAt.isBefore(ref.read(clockProvider).now());
    if (view.isEmpty) {
      return _CartEmpty(expired: expired);
    }
    final fmt = Fmt.of(context);
    return RefreshIndicator(
      color: PicPacColors.accent,
      onRefresh: () => ref.read(cartProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.all(PicPacSpacing.lg),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: view.lines.length + 1,
        separatorBuilder: (context, index) =>
            const SizedBox(height: PicPacSpacing.md),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    view.reconciled
                        ? l10n.cartRecalculated
                        : l10n.cartItemsCount(view.context.cart.items.length),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: FunnelText.secondary),
                  ),
                ),
                const SizedBox(width: PicPacSpacing.sm),
                Flexible(
                  child: Text(
                    l10n.cartExpiresAt(fmt.shortDate(expiresAt)),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: FunnelText.secondary),
                  ),
                ),
              ],
            );
          }
          return _CartLineTile(line: view.lines[index - 1], view: view);
        },
      ),
    );
  }
}

class _CartLineTile extends ConsumerWidget {
  const _CartLineTile({required this.line, required this.view});

  final CartLineView line;
  final CartView view;

  Future<void> _changeQuantity(
    BuildContext context,
    WidgetRef ref,
    int quantity,
  ) async {
    final failure = await ref
        .read(cartProvider.notifier)
        .setQuantity(line.item.id, quantity);
    if (failure == null || !context.mounted) return;
    _report(context, failure);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.cartRemoveTitle),
        content: Text(
          l10n.cartRemoveBody(line.title ?? l10n.cartUnavailableItem),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.actionRemove),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final failure = await ref.read(cartProvider.notifier).remove(line.item.id);
    if (failure == null || !context.mounted) return;
    _report(context, failure);
  }

  void _report(BuildContext context, Failure failure) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.cartUpdateFailed}: ${failureText(l10n, failure)}',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fmt = Fmt.of(context);
    final item = line.item;
    final quantity = view.quantityOf(item);
    final pending = view.isPending(item);
    final title = line.title ?? l10n.cartUnavailableItem;
    final unitLabel = _unitLabel(l10n, quantity);
    final openable = !line.unavailable;
    return Container(
      padding: const EdgeInsets.all(PicPacSpacing.md),
      decoration: BoxDecoration(
        color: PicPacColors.surface,
        borderRadius: BorderRadius.circular(PicPacRadii.card),
        border: Border.all(color: PicPacColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 64,
            height: 64,
            child: ProductArtwork(
              seedId: line.productId ?? item.designId,
              category: line.category ?? 'prints',
              radius: PicPacRadii.photo,
              iconSize: 32,
            ),
          ),
          const SizedBox(width: PicPacSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  container: true,
                  button: openable,
                  label: a11yCartLineLabel(
                    l10n,
                    title: title,
                    quantity: unitLabel,
                  ),
                  excludeSemantics: true,
                  onTap: openable
                      ? () =>
                            context.push(AppRoutes.preflightFor(item.designId))
                      : null,
                  child: InkWell(
                    key: Key('cart-line-${item.id}'),
                    onTap: openable
                        ? () => context.push(
                            AppRoutes.preflightFor(item.designId),
                          )
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: theme.textTheme.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: PicPacSpacing.xxs),
                        Text(
                          unitLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: FunnelText.secondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: PicPacSpacing.xs),
                if (line.isQuantityDerived)
                  Text(
                    l10n.cartQuantityDerived,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: FunnelText.secondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  _QuantityStepper(
                    quantity: quantity,
                    enabled: !pending,
                    onChanged: (next) => _changeQuantity(context, ref, next),
                  ),
              ],
            ),
          ),
          const SizedBox(width: PicPacSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              SizedBox(
                width: kMinTouchTarget,
                height: kMinTouchTarget,
                child: IconButton(
                  tooltip: l10n.actionRemove,
                  onPressed: pending ? null : () => _remove(context, ref),
                  icon: const Icon(Icons.close, size: 20),
                  color: PicPacColors.secondaryText,
                ),
              ),
              const SizedBox(height: PicPacSpacing.xxs),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 96),
                child: Text(
                  fmt.money(item.quote.total),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: PicPacColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _unitLabel(AppLocalizations l10n, int quantity) {
    if (line.isQuantityDerived) return l10n.cartSheetsUnit(quantity);
    final sheets = line.sheets ?? 0;
    final copies = l10n.cartBooksUnit(quantity);
    return sheets <= 0 ? copies : '$copies · ${l10n.cartSpreadsUnit(sheets)}';
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.enabled,
    required this.onChanged,
  });

  final int quantity;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          tooltip: l10n.cartDecrease,
          onPressed: enabled && quantity > 1
              ? () => onChanged(quantity - 1)
              : null,
          icon: const Icon(Icons.remove, size: 20),
          constraints: const BoxConstraints(
            minWidth: kMinTouchTarget,
            minHeight: kMinTouchTarget,
          ),
        ),
        Semantics(
          container: true,
          label: '${l10n.cartQuantity}: $quantity',
          excludeSemantics: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 32),
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ),
        IconButton(
          tooltip: l10n.cartIncrease,
          onPressed: enabled ? () => onChanged(quantity + 1) : null,
          icon: const Icon(Icons.add, size: 20),
          constraints: const BoxConstraints(
            minWidth: kMinTouchTarget,
            minHeight: kMinTouchTarget,
          ),
        ),
      ],
    );
  }
}

class _CartEmpty extends StatelessWidget {
  const _CartEmpty({required this.expired});

  final bool expired;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyView(
      title: expired ? l10n.cartExpiredTitle : l10n.cartEmptyTitle,
      body: expired ? l10n.cartExpiredBody : l10n.cartEmptyBody,
      icon: Icons.shopping_bag_outlined,
      action: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () => context.go(AppRoutes.catalog),
          child: Text(l10n.actionGoCatalog),
        ),
      ),
    );
  }
}

class _CartSummary extends ConsumerWidget {
  const _CartSummary({required this.view});

  final CartView view;

  Future<void> _checkout(BuildContext context, WidgetRef ref) async {
    if (ref.read(sessionServiceProvider).canPlaceOrders) {
      context.push(AppRoutes.checkout);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final work = ref.read(guestWorkProvider);
    if (!work.hasDesign) {
      context.push(AppRoutes.loginFor(AppRoutes.checkout));
      return;
    }
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.checkoutGuestWorkTitle),
        content: Text(l10n.checkoutGuestWorkBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.actionContinue),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return;
    context.push(AppRoutes.loginFor(AppRoutes.checkout));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fmt = Fmt.of(context);
    final canCheckout = view.context.cart.canCheckout;
    final isAccount = ref.watch(sessionControllerProvider).isAccount;
    final hasUnavailable = view.lines.any((line) => line.unavailable);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: PicPacColors.background,
        border: Border(top: BorderSide(color: PicPacColors.border)),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          PicPacSpacing.lg,
          PicPacSpacing.md,
          PicPacSpacing.lg,
          PicPacSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (!canCheckout && hasUnavailable) ...<Widget>[
              Text(
                l10n.cartCannotCheckout,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: PicPacColors.accentText,
                ),
              ),
              const SizedBox(height: PicPacSpacing.sm),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.cartSubtotal,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: PicPacSpacing.sm),
                Flexible(
                  child: Text(
                    fmt.money(view.subtotal),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: PicPacColors.accent,
                    ),
                  ),
                ),
              ],
            ),
            if (view.etaDays > 0) ...<Widget>[
              const SizedBox(height: PicPacSpacing.xxs),
              Text(
                l10n.cartEta(view.etaDays),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: FunnelText.secondary,
                ),
              ),
            ],
            const SizedBox(height: PicPacSpacing.md),
            SizedBox(
              height: 52,
              child: FilledButton(
                key: const Key('cart-checkout'),
                onPressed: canCheckout || !isAccount
                    ? () => _checkout(context, ref)
                    : null,
                child: Text(isAccount ? l10n.actionCheckout : l10n.actionLogin),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
