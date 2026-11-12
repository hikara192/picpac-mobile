import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/di.dart';
import '../clock.dart';
import '../storage/app_database.dart';

enum PendingActionKind {
  checkout('checkout'),

  createTicket('create_ticket'),

  postMessage('post_message'),

  unknown('unknown');

  const PendingActionKind(this.wire);

  final String wire;

  static PendingActionKind fromWire(String? raw) {
    for (final kind in values) {
      if (kind != PendingActionKind.unknown && kind.wire == raw) return kind;
    }
    return PendingActionKind.unknown;
  }
}

final class QueuedAction {
  const QueuedAction({
    required this.id,
    required this.kind,
    required this.payload,
    required this.idempotencyKey,
    required this.attempts,
    required this.createdAt,
  });

  final String id;

  final PendingActionKind kind;

  final String payload;

  final String idempotencyKey;

  final int attempts;

  final DateTime createdAt;

  bool get isExhausted => attempts >= PendingActionsStore.maxAttempts;

  Map<String, Object?>? decodedPayload() {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      return Map<String, Object?>.from(decoded);
    } on Object {
      return null;
    }
  }
}

final class PendingActionsStore {
  PendingActionsStore({
    required this._database,
    this._clock = const SystemClock(),
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  static const int maxAttempts = 5;

  final AppDatabase _database;
  final Clock _clock;
  final Uuid _uuid;

  Future<QueuedAction> add({
    required PendingActionKind kind,
    required Map<String, Object?> payload,
    required String idempotencyKey,
  }) async {
    final action = QueuedAction(
      id: _uuid.v4(),
      kind: kind,
      payload: jsonEncode(payload),
      idempotencyKey: idempotencyKey,
      attempts: 0,
      createdAt: _clock.now().toUtc(),
    );
    await _database
        .into(_database.pendingActions)
        .insert(
          PendingActionsCompanion.insert(
            id: action.id,
            type: kind.wire,
            payload: action.payload,
            idempotencyKey: action.idempotencyKey,
            createdAt: action.createdAt,
          ),
        );
    return action;
  }

  Future<List<QueuedAction>> all() async {
    final rows =
        await (_database.select(_database.pendingActions)
              ..orderBy(<OrderClauseGenerator<$PendingActionsTable>>[
                (table) => OrderingTerm.asc(table.createdAt),
              ]))
            .get();
    return <QueuedAction>[
      for (final row in rows)
        QueuedAction(
          id: row.id,
          kind: PendingActionKind.fromWire(row.type),
          payload: row.payload,
          idempotencyKey: row.idempotencyKey,
          attempts: row.attempts,
          createdAt: row.createdAt,
        ),
    ];
  }

  Future<int> count() async {
    final expression = _database.pendingActions.id.count();
    final query = _database.selectOnly(_database.pendingActions)
      ..addColumns(<Expression<Object>>[expression]);
    final row = await query.getSingle();
    return row.read(expression) ?? 0;
  }

  Future<void> recordAttempt(String id) async {
    final row = await _row(id);
    if (row == null) return;
    await _writeAttempts(id, row.attempts + 1);
  }

  Future<void> exhaust(String id) => _writeAttempts(id, maxAttempts);

  Future<void> resetAttempts(String id) => _writeAttempts(id, 0);

  Future<void> remove(String id) async {
    await (_database.delete(
      _database.pendingActions,
    )..where((table) => table.id.equals(id))).go();
  }

  Future<void> clear() => _database.delete(_database.pendingActions).go();

  Future<void> _writeAttempts(String id, int attempts) async {
    await (_database.update(_database.pendingActions)
          ..where((table) => table.id.equals(id)))
        .write(PendingActionsCompanion(attempts: Value(attempts)));
  }

  Future<PendingAction?> _row(String id) => (_database.select(
    _database.pendingActions,
  )..where((table) => table.id.equals(id))).getSingleOrNull();
}

final Provider<PendingActionsStore> pendingActionsStoreProvider =
    Provider<PendingActionsStore>(
      (ref) => PendingActionsStore(
        database: ref.watch(databaseProvider),
        clock: ref.watch(clockProvider),
      ),
    );
