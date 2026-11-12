import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di.dart';
import '../clock.dart';
import '../storage/app_database.dart';

final class OrderCache {
  OrderCache({required this._database, this.clock = const SystemClock()});

  final AppDatabase _database;

  final Clock clock;

  Future<void> save(Order order) async {
    await _database
        .into(_database.ordersCache)
        .insertOnConflictUpdate(
          OrdersCacheCompanion.insert(
            orderId: order.id,
            number: order.number,
            payload: jsonEncode(order.toJson()),
            updatedAt: clock.now(),
          ),
        );
  }

  Future<void> saveAll(Iterable<Order> orders) async {
    await _database.batch((batch) {
      for (final order in orders) {
        batch.insert(
          _database.ordersCache,
          OrdersCacheCompanion.insert(
            orderId: order.id,
            number: order.number,
            payload: jsonEncode(order.toJson()),
            updatedAt: clock.now(),
          ),
          onConflict: DoUpdate(
            (_) => OrdersCacheCompanion(
              number: Value(order.number),
              payload: Value(jsonEncode(order.toJson())),
              updatedAt: Value(clock.now()),
            ),
          ),
        );
      }
    });
  }

  Future<Order?> load(String orderId) async {
    final row = await (_database.select(
      _database.ordersCache,
    )..where((table) => table.orderId.equals(orderId))).getSingleOrNull();
    return row == null ? null : parse(row.payload);
  }

  Future<List<Order>> recent({int limit = 50}) async {
    final rows =
        await (_database.select(_database.ordersCache)
              ..orderBy(<OrderClauseGenerator<$OrdersCacheTable>>[
                (table) => OrderingTerm.desc(table.updatedAt),
              ])
              ..limit(limit))
            .get();
    return <Order>[for (final row in rows) ?parse(row.payload)];
  }

  Future<void> clear() => _database.delete(_database.ordersCache).go();

  static Order? parse(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      return Order.fromJson(Map<String, Object?>.from(decoded));
    } on Object {
      return null;
    }
  }
}

final Provider<OrderCache> orderCacheProvider = Provider<OrderCache>(
  (ref) => OrderCache(
    database: ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);
