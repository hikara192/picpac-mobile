import 'dart:math' as math;

import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di.dart';
import '../app_logger.dart';
import '../clock.dart';
import '../orders/order_cache.dart';
import 'pending_actions.dart';

final class OfflineQueueReport {
  const OfflineQueueReport({
    this.sent = 0,
    this.failed = 0,
    this.remaining = 0,
    this.orderNumbers = const <String>[],
  });

  final int sent;

  final int failed;

  final int remaining;

  final List<String> orderNumbers;

  bool get isEmpty => sent == 0 && failed == 0;

  bool get hasSent => sent > 0;
}

final class OfflineQueue {
  OfflineQueue({
    required this._api,
    required this._store,
    required this._orders,
    required this._logger,
    this._clock = const SystemClock(),
  });

  final ApiPort _api;
  final PendingActionsStore _store;
  final OrderCache _orders;
  final AppLogger _logger;
  final Clock _clock;

  final Map<String, DateTime> _nextAttemptAt = <String, DateTime>{};
  bool _running = false;

  static bool shouldQueue(Failure failure) =>
      failure.code == ApiErrorCode.networkUnavailable ||
      failure.code == ApiErrorCode.timeout;

  Future<QueuedAction> enqueueCheckout(
    CheckoutRequest request, {
    required String idempotencyKey,
  }) => _store.add(
    kind: PendingActionKind.checkout,
    payload: request.toJson(),
    idempotencyKey: idempotencyKey,
  );

  Future<QueuedAction> enqueueTicket(
    CreateTicketRequest request, {
    required String idempotencyKey,
  }) => _store.add(
    kind: PendingActionKind.createTicket,
    payload: request.toJson(),
    idempotencyKey: idempotencyKey,
  );

  Future<QueuedAction> enqueueMessage(
    PostTicketMessageRequest request, {
    required String idempotencyKey,
  }) => _store.add(
    kind: PendingActionKind.postMessage,
    payload: request.toJson(),
    idempotencyKey: idempotencyKey,
  );

  Future<OfflineQueueReport> process({bool manual = false}) async {
    if (_running) return const OfflineQueueReport();
    _running = true;
    try {
      final rows = await _store.all();
      var sent = 0;
      var failed = 0;
      final numbers = <String>[];
      for (final row in rows) {
        if (row.kind == PendingActionKind.unknown) continue;
        if (manual && row.isExhausted) {
          await _store.resetAttempts(row.id);
        } else if (!manual) {
          if (row.isExhausted) continue;
          final next = _nextAttemptAt[row.id];
          if (next != null && next.isAfter(_clock.now())) continue;
        }
        final outcome = await _execute(row);
        if (outcome.dropped) continue;
        if (outcome.sent) {
          sent++;
          if (outcome.orderNumber != null) numbers.add(outcome.orderNumber!);
          _nextAttemptAt.remove(row.id);
          await _store.remove(row.id);
          continue;
        }
        failed++;
        final failure = outcome.failure;
        if (failure == null) continue;
        if (_isRetryable(failure)) {
          await _store.recordAttempt(row.id);
          _nextAttemptAt[row.id] = _clock.now().add(_backoff(row.attempts + 1));
        } else {
          await _store.exhaust(row.id);
        }
        _logger.warning('offline.action_failed', <String, Object?>{
          'type': row.kind.wire,
          'code': failure.code,
          'attempts': row.attempts + 1,
        });
      }
      return OfflineQueueReport(
        sent: sent,
        failed: failed,
        remaining: await _store.count(),
        orderNumbers: List<String>.unmodifiable(numbers),
      );
    } finally {
      _running = false;
    }
  }

  Future<OfflineQueueReport> retry(String id) async {
    QueuedAction? action;
    for (final row in await _store.all()) {
      if (row.id == id) action = row;
    }
    if (action == null) return const OfflineQueueReport();
    await _store.resetAttempts(action.id);
    _nextAttemptAt.remove(action.id);
    return process(manual: true);
  }

  Future<_Outcome> _execute(QueuedAction action) async {
    final payload = action.decodedPayload();
    if (payload == null) {
      await _store.remove(action.id);
      _logger.warning('offline.payload_invalid', <String, Object?>{
        'type': action.kind.wire,
      });
      return const _Outcome.dropped_();
    }
    try {
      switch (action.kind) {
        case PendingActionKind.checkout:
          final result = await _api.checkout(
            CheckoutRequest.fromJson(payload),
            idempotencyKey: action.idempotencyKey,
          );
          if (result case Ok<Order>(:final value)) {
            await _orders.save(value);
            return _Outcome.sent_(orderNumber: value.number);
          }
          return _Outcome.failed_(result.failureOrNull);
        case PendingActionKind.createTicket:
          final result = await _api.createSupportTicket(
            CreateTicketRequest.fromJson(payload),
            idempotencyKey: action.idempotencyKey,
          );
          return result is Ok<SupportTicket>
              ? const _Outcome.sent_(orderNumber: null)
              : _Outcome.failed_(result.failureOrNull);
        case PendingActionKind.postMessage:
          final result = await _api.postTicketMessage(
            PostTicketMessageRequest.fromJson(payload),
            idempotencyKey: action.idempotencyKey,
          );
          return result is Ok<SupportTicket>
              ? const _Outcome.sent_(orderNumber: null)
              : _Outcome.failed_(result.failureOrNull);
        case PendingActionKind.unknown:
          return const _Outcome.dropped_();
      }
    } on Object catch (error) {
      _logger.warning('offline.payload_invalid', <String, Object?>{
        'type': action.kind.wire,
        'error': '${error.runtimeType}',
      });
      await _store.remove(action.id);
      return const _Outcome.dropped_();
    }
  }

  static bool _isRetryable(Failure failure) =>
      failure.code == ApiErrorCode.networkUnavailable ||
      failure.code == ApiErrorCode.timeout ||
      failure.code == ApiErrorCode.serverError ||
      failure.code == ApiErrorCode.rateLimited;

  static Duration _backoff(int attempts) =>
      Duration(seconds: math.min(60, 1 << math.min(attempts, 6)));
}

final class _Outcome {
  const _Outcome.sent_({required this.orderNumber})
    : sent = true,
      dropped = false,
      failure = null;

  const _Outcome.failed_(this.failure)
    : sent = false,
      dropped = false,
      orderNumber = null;

  const _Outcome.dropped_()
    : sent = false,
      dropped = true,
      failure = null,
      orderNumber = null;

  final bool sent;
  final bool dropped;
  final Failure? failure;
  final String? orderNumber;
}

final Provider<OfflineQueue> offlineQueueProvider = Provider<OfflineQueue>(
  (ref) => OfflineQueue(
    api: ref.watch(apiPortProvider),
    store: ref.watch(pendingActionsStoreProvider),
    orders: ref.watch(orderCacheProvider),
    logger: ref.watch(loggerProvider),
    clock: ref.watch(clockProvider),
  ),
);

final class PendingActionsController extends AsyncNotifier<List<QueuedAction>> {
  @override
  Future<List<QueuedAction>> build() =>
      ref.watch(pendingActionsStoreProvider).all();

  Future<void> refresh() async {
    final rows = await ref.read(pendingActionsStoreProvider).all();
    if (!ref.mounted) return;
    state = AsyncData<List<QueuedAction>>(rows);
  }

  Future<OfflineQueueReport> run({bool manual = false}) async {
    final report = await ref.read(offlineQueueProvider).process(manual: manual);
    await refresh();
    return report;
  }

  Future<OfflineQueueReport> retry(String id) async {
    final report = await ref.read(offlineQueueProvider).retry(id);
    await refresh();
    return report;
  }

  Future<void> clear() async {
    await ref.read(pendingActionsStoreProvider).clear();
    if (ref.mounted) {
      state = const AsyncData<List<QueuedAction>>(<QueuedAction>[]);
    }
  }
}

final pendingActionsControllerProvider =
    AsyncNotifierProvider<PendingActionsController, List<QueuedAction>>(
      PendingActionsController.new,
      retry: (retryCount, error) => null,
    );
