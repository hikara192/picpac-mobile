import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di.dart';
import '../session/session_service.dart';
import 'order_cache.dart';

final class OrderSnapshot {
  const OrderSnapshot({required this.order, this.stale = false});

  final Order order;

  final bool stale;
}

final class OrderHistorySnapshot {
  const OrderHistorySnapshot({
    required this.orders,
    this.nextCursor,
    this.stale = false,
  });

  final List<Order> orders;

  final String? nextCursor;

  final bool stale;

  bool get hasMore => nextCursor != null;
}

final class OrdersRepository {
  OrdersRepository({
    required this._api,
    required this._session,
    required this._cache,
  });

  final ApiPort _api;
  final SessionService _session;
  final OrderCache _cache;

  Future<Result<OrderHistorySnapshot>> page({
    String? cursor,
    int limit = 20,
    OrderStatus? status,
  }) async {
    final result = await _session.ensureSession(
      () => _api.orders(cursor: cursor, limit: limit, status: status),
    );
    switch (result) {
      case Ok<OrderHistoryPage>(:final value):
        await _cache.saveAll(value.orders);
        return Ok<OrderHistorySnapshot>(
          OrderHistorySnapshot(
            orders: value.orders,
            nextCursor: value.nextCursor,
          ),
        );
      case Err<OrderHistoryPage>(:final error):
        if (cursor != null || status != null || !_isOffline(error)) {
          return Err<OrderHistorySnapshot>(error);
        }
        final cached = await _cache.recent();
        if (cached.isEmpty) return Err<OrderHistorySnapshot>(error);
        return Ok<OrderHistorySnapshot>(
          OrderHistorySnapshot(orders: cached, stale: true),
        );
    }
  }

  Future<Result<OrderSnapshot>> order(String orderId) async {
    final result = await _session.ensureSession(() => _api.order(orderId));
    switch (result) {
      case Ok<Order>(:final value):
        await _cache.save(value);
        return Ok<OrderSnapshot>(OrderSnapshot(order: value));
      case Err<Order>(:final error):
        final cached = await _cache.load(orderId);
        if (cached == null || !_isOffline(error)) {
          return Err<OrderSnapshot>(error);
        }
        return Ok<OrderSnapshot>(OrderSnapshot(order: cached, stale: true));
    }
  }

  Future<Result<Order>> lookup({
    required String number,
    required String phoneLast4,
  }) async {
    final result = await _api.lookupOrder(
      number: number,
      phoneLast4: phoneLast4,
    );
    if (result case Ok<Order>(:final value)) await _cache.save(value);
    return result;
  }

  Future<Order?> cached(String orderId) => _cache.load(orderId);

  Future<void> remember(Order order) => _cache.save(order);

  static bool _isOffline(Failure failure) =>
      failure.code == ApiErrorCode.networkUnavailable ||
      failure.code == ApiErrorCode.timeout ||
      failure.code == ApiErrorCode.serverError;
}

final Provider<OrdersRepository> ordersRepositoryProvider =
    Provider<OrdersRepository>(
      (ref) => OrdersRepository(
        api: ref.watch(apiPortProvider),
        session: ref.watch(sessionServiceProvider),
        cache: ref.watch(orderCacheProvider),
      ),
    );
