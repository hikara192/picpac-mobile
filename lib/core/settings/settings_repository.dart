import '../storage/app_database.dart';

final class SettingsRepository {
  SettingsRepository(this._database);

  final AppDatabase _database;

  static const String localeKey = 'locale';

  Future<String?> read(String key) async {
    final query = _database.select(_database.appSettings)
      ..where((AppSettings row) => row.key.equals(key));
    final row = await query.getSingleOrNull();
    return row?.value;
  }

  Future<void> write(String key, String value) => _database
      .into(_database.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: key, value: value),
      );

  Future<void> remove(String key) async {
    await (_database.delete(
      _database.appSettings,
    )..where((AppSettings row) => row.key.equals(key))).go();
  }
}
