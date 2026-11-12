import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class DraftIndex extends Table {
  TextColumn get designId => text()();

  TextColumn get productId => text()();

  IntColumn get revision => integer()();

  TextColumn get title => text().withDefault(const Constant(''))();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{designId};
}

class OrdersCache extends Table {
  TextColumn get orderId => text()();

  TextColumn get number => text()();

  TextColumn get payload => text()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{orderId};
}

class PendingActions extends Table {
  TextColumn get id => text()();

  TextColumn get type => text()();

  TextColumn get payload => text()();

  TextColumn get idempotencyKey => text()();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class AppSettings extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

@DriftDatabase(
  tables: <Type>[DraftIndex, OrdersCache, PendingActions, AppSettings],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.connection);

  AppDatabase.open() : super(driftDatabase(name: 'picpac'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async => m.createAll(),
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(appSettings);
      }
    },
  );
}
