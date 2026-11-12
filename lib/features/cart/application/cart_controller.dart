import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../core/analytics.dart';
import '../../../core/orders/cart_pricing.dart';
import '../../../core/orders/cart_repository.dart';
import '../../../core/session/session_controller.dart';
import '../../_shared/application/async_retry.dart';

final class CartLineView {
  const CartLineView({
    required this.item,
    this.title,
    this.productId,
    this.category,
    this.unavailable = false,
    this.unit = PricingUnit.sheet,
    this.sheets,
  });

  final CartItem item;

  final String? title;

  final String? productId;

  final String? category;

  final bool unavailable;

  final PricingUnit unit;

  final int? sheets;

  bool get isPerSheet => unit.isSheet;

  bool get isQuantityDerived => isPerSheet;
}

final class CartView {
  const CartView({
    required this.context,
    required this.lines,
    this.pendingItemId,
    this.pendingQuantity,
    this.reconciled = false,
  });

  final CartContext context;

  final List<CartLineView> lines;

  final String? pendingItemId;

  final int? pendingQuantity;

  final bool reconciled;

  Money get subtotal => context.cart.subtotal;

  bool get isEmpty => context.cart.items.isEmpty;

  int get etaDays => context.cart.items.fold<int>(
    0,
    (max, item) => item.quote.etaDays > max ? item.quote.etaDays : max,
  );

  int quantityOf(CartItem item) => item.id == pendingItemId
      ? pendingQuantity ?? item.quantity
      : item.quantity;

  bool isPending(CartItem item) => item.id == pendingItemId;

  factory CartView.fromContext(CartContext context) => CartView(
    context: context,
    lines: <CartLineView>[
      for (final item in context.cart.items)
        CartLineView(
          item: item,
          title: context.titleOf(item.designId),
          productId: context.productOf(item.designId)?.id,
          category: context.productOf(item.designId)?.category,
          unavailable: context.isUnavailable(item.designId),
          unit: context.unitOf(item.designId),
          sheets: context.sheetsOf(item.designId),
        ),
    ],
    reconciled: context.reconciled,
  );

  CartView withPending(String itemId, int quantity) => CartView(
    context: context,
    lines: lines,
    pendingItemId: itemId,
    pendingQuantity: quantity,
    reconciled: reconciled,
  );
}

final class CartController extends AsyncNotifier<CartView> {
  @override
  Future<CartView> build() async {
    final analytics = ref.watch(analyticsProvider);
    ref.watch(sessionControllerProvider);
    final result = await ref.watch(cartRepositoryProvider).load();
    return result.fold(
      ok: (context) {
        analytics.track(AnalyticsEvent.cartViewed, <String, Object?>{
          'items': context.cart.items.length,
          'units': context.cart.unitCount,
        });
        return CartView.fromContext(context);
      },
      err: (failure) => throw failure,
    );
  }

  bool get isExpired {
    final cart = state.value?.context.cart;
    if (cart == null) return false;
    return cart.expiresAt.isBefore(ref.read(clockProvider).now());
  }

  Future<Failure?> setQuantity(String itemId, int quantity) async {
    final current = state.value;
    if (current == null || quantity < 1) return null;
    state = AsyncData<CartView>(current.withPending(itemId, quantity));
    final result = await ref
        .read(cartRepositoryProvider)
        .setQuantity(itemId, quantity);
    if (!ref.mounted) return result.failureOrNull;
    return result.fold(
      ok: (cart) {
        state = AsyncData<CartView>(
          CartView.fromContext(
            current.context.withCart(cart, reconciled: false),
          ),
        );
        ref.read(cartRevisionProvider.notifier).bump();
        return null;
      },
      err: (failure) {
        state = AsyncData<CartView>(current);
        return failure;
      },
    );
  }

  Future<Failure?> remove(String itemId) async {
    final current = state.value;
    if (current == null) return null;
    final result = await ref.read(cartRepositoryProvider).remove(itemId);
    if (!ref.mounted) return result.failureOrNull;
    return result.fold(
      ok: (cart) {
        state = AsyncData<CartView>(
          CartView.fromContext(
            current.context.withCart(cart, reconciled: false),
          ),
        );
        ref.read(cartRevisionProvider.notifier).bump();
        return null;
      },
      err: (failure) => failure,
    );
  }

  Future<void> refresh() async {
    final current = state.value;
    if (current != null) state = AsyncData<CartView>(current);
    final result = await ref.read(cartRepositoryProvider).load(force: true);
    if (!ref.mounted) return;
    state = result.fold(
      ok: (context) => AsyncData<CartView>(CartView.fromContext(context)),
      err: (failure) => AsyncError<CartView>(failure, StackTrace.current),
    );
  }
}

final cartProvider = AsyncNotifierProvider<CartController, CartView>(
  CartController.new,
  retry: noProviderRetry,
);
