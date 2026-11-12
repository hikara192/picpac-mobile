import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/offline/offline_queue.dart';
import '../../../app/di.dart';
import '../../../core/analytics.dart';
import '../../../core/orders/cart_repository.dart';
import '../../../core/orders/orders_repository.dart';
import '../../../core/orders/preflight_ack.dart';
import '../../../core/session/session_service.dart';
import '../../../core/session/session_controller.dart';
import '../../_shared/application/async_retry.dart';

final class DeliveryChoice {
  const DeliveryChoice({
    required this.optionId,
    required this.kind,
    this.pointId,
    this.slot,
    this.address = '',
  });

  final String optionId;

  final DeliveryKind kind;

  final String? pointId;

  final DateTime? slot;

  final String address;

  bool get isComplete => kind == DeliveryKind.pickup
      ? pointId != null && slot != null
      : address.trim().length >= 5;

  DeliverySelection toSelection() => DeliverySelection(
    kind: kind,
    optionId: optionId,
    pointId: pointId,
    slot: slot,
    address: kind == DeliveryKind.pickup ? null : address.trim(),
  );

  DeliveryChoice copyWith({
    String? optionId,
    DeliveryKind? kind,
    String? pointId,
    DateTime? slot,
    String? address,
  }) => DeliveryChoice(
    optionId: optionId ?? this.optionId,
    kind: kind ?? this.kind,
    pointId: pointId ?? this.pointId,
    slot: slot ?? this.slot,
    address: address ?? this.address,
  );

  @override
  bool operator ==(Object other) =>
      other is DeliveryChoice &&
      other.optionId == optionId &&
      other.kind == kind &&
      other.pointId == pointId &&
      other.slot == slot &&
      other.address.trim() == address.trim();

  @override
  int get hashCode =>
      Object.hash(optionId, kind, pointId, slot, address.trim());
}

final class CheckoutData {
  const CheckoutData({
    required this.cart,
    required this.options,
    required this.points,
  });

  final CartContext cart;

  final List<DeliveryOption> options;

  final List<PickupPoint> points;

  bool get isEmpty => cart.cart.items.isEmpty;

  DeliveryOption? optionById(String id) {
    for (final option in options) {
      if (option.id == id) return option;
    }
    return null;
  }

  PickupPoint? pointById(String? id) {
    if (id == null) return null;
    for (final point in points) {
      if (point.id == id) return point;
    }
    return null;
  }

  DeliveryChoice get defaultChoice {
    DeliveryOption? preferred;
    for (final option in options) {
      if (option.kind == DeliveryKind.pickup) {
        preferred = option;
        break;
      }
    }
    final option = preferred ?? (options.isEmpty ? null : options.first);
    if (option == null) {
      return const DeliveryChoice(optionId: '', kind: DeliveryKind.unknown);
    }
    return DeliveryChoice(
      optionId: option.id,
      kind: option.kind,
      pointId: option.requiresPoint && points.isNotEmpty
          ? points.first.id
          : null,
    );
  }

  CheckoutData withCart(CartContext refreshed) =>
      CheckoutData(cart: refreshed, options: options, points: points);
}

final class SummaryLine {
  const SummaryLine({required this.labelKey, required this.amount});

  final String labelKey;

  final Money amount;
}

final class CheckoutSummary {
  const CheckoutSummary({
    required this.lines,
    required this.total,
    this.etaDays = 0,
    this.exact = false,
    this.canOrder = true,
  });

  final List<SummaryLine> lines;

  final Money total;

  final int etaDays;

  final bool exact;

  final bool canOrder;
}

final class CheckoutPreflightIssue {
  const CheckoutPreflightIssue({required this.designId, required this.issue});

  final String designId;

  final PreflightIssue issue;
}

final class CheckoutPreflightVerdict {
  const CheckoutPreflightVerdict({
    this.issues = const <CheckoutPreflightIssue>[],
    this.revisions = const <String, int>{},
    this.acknowledged = false,
  });

  final List<CheckoutPreflightIssue> issues;

  final Map<String, int> revisions;

  final bool acknowledged;

  bool get isBlocked => issues.isNotEmpty;

  bool get needsConfirmation => issues.isNotEmpty && !acknowledged;

  String? get firstDesignId => issues.isEmpty ? null : issues.first.designId;
}

final class CheckoutController extends AsyncNotifier<CheckoutData> {
  @override
  Future<CheckoutData> build() async {
    ref.watch(cartRevisionProvider);
    ref.watch(sessionControllerProvider);
    final repository = ref.watch(cartRepositoryProvider);
    final api = ref.watch(apiPortProvider);
    final cartResult = await repository.load();
    final cart = cartResult.fold(
      ok: (value) => value,
      err: (failure) => throw failure,
    );
    if (cart.cart.items.isEmpty) {
      return CheckoutData(
        cart: cart,
        options: const <DeliveryOption>[],
        points: const <PickupPoint>[],
      );
    }
    final optionsResult = await api.deliveryOptions();
    final options = optionsResult.fold(
      ok: (value) => value,
      err: (failure) => throw failure,
    );
    final pointsResult = await api.pickupPoints();
    final points = pointsResult.fold(
      ok: (value) => value,
      err: (failure) => throw failure,
    );
    final data = CheckoutData(cart: cart, options: options, points: points);
    ref.read(analyticsProvider).track(
      AnalyticsEvent.checkoutStarted,
      <String, Object?>{
        'items': cart.cart.items.length,
        'deliveryOptions': options.length,
      },
    );
    return data;
  }

  Future<Failure?> applyPromo(String? code) async {
    final current = state.value;
    if (current == null) return null;
    final result = await ref.read(cartRepositoryProvider).setPromo(code);
    if (!ref.mounted) return result.failureOrNull;
    switch (result) {
      case Ok<Cart>(:final value):
        state = AsyncData<CheckoutData>(
          current.withCart(current.cart.withCart(value)),
        );
        return null;
      case Err<Cart>(:final error):
        return error;
    }
  }

  Future<CheckoutPreflightVerdict> checkPreflight() async {
    final data = state.value;
    if (data == null || data.cart.cart.items.isEmpty) {
      return const CheckoutPreflightVerdict();
    }
    final api = ref.read(apiPortProvider);
    final session = ref.read(sessionServiceProvider);
    final acks = ref.read(preflightAckProvider);
    final issues = <CheckoutPreflightIssue>[];
    final revisions = <String, int>{};
    var acknowledged = true;
    for (final item in data.cart.cart.items) {
      final result = await session.ensureSession(
        () => api.preflight(item.designId),
      );
      if (result case Ok<PreflightDto>(:final value)) {
        final blocking = <PreflightIssue>[
          for (final issue in value.issues)
            if (issue.isBlocking) issue,
        ];
        if (blocking.isEmpty) continue;
        revisions[item.designId] = value.revision;
        if (!acks.covers(item.designId, value.revision)) acknowledged = false;
        for (final issue in blocking) {
          issues.add(
            CheckoutPreflightIssue(designId: item.designId, issue: issue),
          );
        }
      }
    }
    return CheckoutPreflightVerdict(
      issues: issues,
      revisions: revisions,
      acknowledged: issues.isEmpty || acknowledged,
    );
  }

  void acknowledge(CheckoutPreflightVerdict verdict) {
    final store = ref.read(preflightAckProvider.notifier);
    for (final entry in verdict.revisions.entries) {
      store.acknowledge(entry.key, entry.value);
    }
  }

  Future<Result<Order>> submit({
    required DeliveryChoice choice,
    required String name,
    required String phone,
  }) async {
    final data = state.value;
    if (data == null) {
      return Err<Order>(
        const ApiFailure(
          code: ApiErrorCode.networkUnavailable,
          message: 'checkout data is not loaded yet',
        ),
      );
    }
    final key = ref
        .read(checkoutAttemptProvider.notifier)
        .keyFor(data.cart.cart.id);
    final request = CheckoutRequest(
      cartId: data.cart.cart.id,
      delivery: choice.toSelection(),
      contact: ContactInfo(name: name.trim(), phone: phone.trim()),
      promoCode: data.cart.cart.promoCode,
    );
    final result = await ref
        .read(apiPortProvider)
        .checkout(request, idempotencyKey: key);
    if (result is Err<Order> && OfflineQueue.shouldQueue(result.error)) {
      await ref
          .read(offlineQueueProvider)
          .enqueueCheckout(request, idempotencyKey: key);
    }
    if (result case Ok<Order>(:final value)) {
      ref.read(checkoutAttemptProvider.notifier).complete();
      await ref.read(ordersRepositoryProvider).remember(value);
      ref.read(analyticsProvider).track(
        AnalyticsEvent.orderCreated,
        <String, Object?>{
          'orderId': value.id,
          'items': value.items.length,
          'totalMinor': value.totals.total.amountMinor,
          'currency': value.totals.total.currency,
        },
      );
      if (ref.mounted) ref.invalidateSelf();
    }
    return result;
  }
}

final checkoutProvider =
    AsyncNotifierProvider<CheckoutController, CheckoutData>(
      CheckoutController.new,
      retry: noProviderRetry,
    );

final checkoutSummaryProvider =
    FutureProvider.family<CheckoutSummary, DeliveryChoice>((ref, choice) async {
      final api = ref.watch(apiPortProvider);
      final data = await ref.watch(checkoutProvider.future);
      final cart = data.cart.cart;
      final currency = cart.subtotal.currency;
      if (cart.items.isEmpty) {
        return CheckoutSummary(
          lines: const <SummaryLine>[],
          total: Money.zero(currency),
          canOrder: false,
        );
      }
      final item = cart.items.length == 1 ? cart.items.first : null;
      final design = item == null ? null : data.cart.designs[item.designId];
      final product = item == null ? null : data.cart.productOf(item.designId);
      final format = item == null ? null : data.cart.formatOf(item.designId);
      if (item != null && design != null && product != null && format != null) {
        final quote = await api.price(
          PriceRequest(
            productId: product.id,
            formatId: format.id,
            options: design.document.product.options,
            spreadsCount: data.cart.unitsOf(item),
            designId: item.designId,
            promoCode: cart.promoCode,
            delivery: choice.isComplete ? choice.toSelection() : null,
          ),
        );
        if (quote case Ok<PriceQuote>(:final value)) {
          return CheckoutSummary(
            lines: <SummaryLine>[
              for (final line in value.breakdown)
                SummaryLine(labelKey: line.labelKey, amount: line.amount),
            ],
            total: value.total,
            etaDays: value.etaDays,
            exact: choice.isComplete,
            canOrder: value.canOrder,
          );
        }
      }

      final quotes = <PriceQuote>[];
      for (var index = 0; index < cart.items.length; index++) {
        final line = cart.items[index];
        final lineDesign = data.cart.designs[line.designId];
        final lineProduct = data.cart.productOf(line.designId);
        final lineFormat = data.cart.formatOf(line.designId);
        if (lineDesign == null || lineProduct == null || lineFormat == null) {
          return CheckoutSummary(
            lines: const <SummaryLine>[],
            total: cart.subtotal,
            canOrder: false,
          );
        }
        final quote = await api.price(
          PriceRequest(
            productId: lineProduct.id,
            formatId: lineFormat.id,
            options: lineDesign.document.product.options,
            spreadsCount: data.cart.unitsOf(line),
            designId: line.designId,
            promoCode: cart.promoCode,
            delivery: index == 0 && choice.isComplete
                ? choice.toSelection()
                : null,
          ),
        );
        switch (quote) {
          case Ok<PriceQuote>(:final value):
            quotes.add(value);
          case Err<PriceQuote>(:final error):
            throw error;
        }
      }

      final lines = <SummaryLine>[];
      var total = Money.zero(currency);
      var eta = 0;
      for (final quote in quotes) {
        for (final line in quote.breakdown) {
          lines.add(SummaryLine(labelKey: line.labelKey, amount: line.amount));
        }
        total = total + quote.total;
        if (quote.etaDays > eta) eta = quote.etaDays;
      }
      return CheckoutSummary(
        lines: lines,
        total: total,
        etaDays: eta,
        exact: false,
        canOrder: cart.canCheckout && quotes.every((quote) => quote.canOrder),
      );
    }, isAutoDispose: true);

final class CheckoutAttempt extends Notifier<CheckoutAttemptState> {
  @override
  CheckoutAttemptState build() => const CheckoutAttemptState();

  String keyFor(String cartId) {
    final current = state;
    final key = current.key;
    if (current.cartId == cartId && key != null) return key;
    final minted = const Uuid().v4();
    state = CheckoutAttemptState(cartId: cartId, key: minted);
    return minted;
  }

  void complete() => state = const CheckoutAttemptState();
}

final class CheckoutAttemptState {
  const CheckoutAttemptState({this.cartId, this.key});

  final String? cartId;

  final String? key;
}

final checkoutAttemptProvider =
    NotifierProvider<CheckoutAttempt, CheckoutAttemptState>(
      CheckoutAttempt.new,
    );
