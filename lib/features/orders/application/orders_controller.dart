import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics.dart';
import '../../../app/di.dart';
import '../../../core/orders/orders_repository.dart';
import '../../_shared/application/async_retry.dart';

final class OrdersController extends AsyncNotifier<OrderHistorySnapshot> {
  bool loadingMore = false;

  @override
  Future<OrderHistorySnapshot> build() async {
    final result = await ref
        .watch(ordersRepositoryProvider)
        .page(limit: pageSize);
    return result.fold(ok: (page) => page, err: (failure) => throw failure);
  }

  static const int pageSize = 20;

  Future<Failure?> loadMore() async {
    final current = state.value;
    final cursor = current?.nextCursor;
    if (current == null || cursor == null || loadingMore) return null;
    loadingMore = true;
    final result = await ref
        .read(ordersRepositoryProvider)
        .page(cursor: cursor, limit: pageSize);
    loadingMore = false;
    if (!ref.mounted) return result.failureOrNull;
    return result.fold(
      ok: (page) {
        state = AsyncData<OrderHistorySnapshot>(
          OrderHistorySnapshot(
            orders: <Order>[...current.orders, ...page.orders],
            nextCursor: page.nextCursor,
            stale: current.stale || page.stale,
          ),
        );
        return null;
      },
      err: (failure) => failure,
    );
  }

  Future<Failure?> reload() async {
    try {
      ref.invalidate(ordersProvider);
      await ref.read(ordersProvider.future);
      return null;
    } on Object catch (error) {
      return failureOr(error);
    }
  }
}

final ordersProvider =
    AsyncNotifierProvider<OrdersController, OrderHistorySnapshot>(
      OrdersController.new,
      isAutoDispose: true,
      retry: noProviderRetry,
    );

final class OrderDetailView {
  const OrderDetailView({
    required this.snapshot,
    this.pickupPoint,
    this.deliveryOption,
  });

  final OrderSnapshot snapshot;

  final PickupPoint? pickupPoint;

  final DeliveryOption? deliveryOption;
}

final class OrderDetailController extends AsyncNotifier<OrderDetailView> {
  OrderDetailController(this.orderId);

  final String orderId;

  @override
  Future<OrderDetailView> build() async {
    final repository = ref.watch(ordersRepositoryProvider);
    final result = await repository.order(orderId);
    final snapshot = result.fold(
      ok: (value) => value,
      err: (failure) => throw failure,
    );
    final delivery = snapshot.order.delivery;
    final pointId = delivery.pointId;
    final optionId = delivery.optionId;
    final point = delivery.isPickup && pointId != null
        ? await ref.watch(pickupPointProvider(pointId).future)
        : null;
    final option = optionId == null
        ? null
        : await ref.watch(deliveryOptionProvider(optionId).future);
    ref.read(analyticsProvider).track(
      AnalyticsEvent.orderOpened,
      <String, Object?>{'orderId': snapshot.order.id, 'stale': snapshot.stale},
    );
    return OrderDetailView(
      snapshot: snapshot,
      pickupPoint: point,
      deliveryOption: option,
    );
  }
}

final pickupPointProvider = FutureProvider.family<PickupPoint?, String>((
  ref,
  pointId,
) async {
  final result = await ref.watch(apiPortProvider).pickupPoints();
  for (final point in result.valueOrNull ?? const <PickupPoint>[]) {
    if (point.id == pointId) return point;
  }
  return null;
}, retry: noProviderRetry);

final deliveryOptionProvider = FutureProvider.family<DeliveryOption?, String>((
  ref,
  optionId,
) async {
  final result = await ref.watch(apiPortProvider).deliveryOptions();
  for (final option in result.valueOrNull ?? const <DeliveryOption>[]) {
    if (option.id == optionId) return option;
  }
  return null;
}, retry: noProviderRetry);

final orderDetailProvider =
    AsyncNotifierProvider.family<
      OrderDetailController,
      OrderDetailView,
      String
    >(OrderDetailController.new, isAutoDispose: true, retry: noProviderRetry);
