import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/core/settings/settings_repository.dart';
import 'package:picpac_mobile/core/storage/app_database.dart';

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('picpac_migration_');
    file = File('${directory.path}/picpac.sqlite');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  Future<void> rewindToSchemaOne(AppDatabase database) async {
    await database.customStatement('DROP TABLE app_settings');
    await database.customStatement('PRAGMA user_version = 1');
  }

  test('схема 1 → 2: app_settings создаётся, черновик и очередь целы', () async {
    final seededAt = DateTime(2026, 10, 1, 9, 30);

    var database = AppDatabase(NativeDatabase(file));
    await database
        .into(database.draftIndex)
        .insert(
          DraftIndexCompanion.insert(
            designId: 'dsg_legacy',
            productId: 'photo_print',
            revision: 7,
            updatedAt: seededAt,
            title: const Value('Печать 10×15'),
          ),
        );
    await database
        .into(database.pendingActions)
        .insert(
          PendingActionsCompanion.insert(
            id: 'act_1',
            type: 'checkout',
            payload: '{"cartId":"cart_1"}',
            idempotencyKey: 'key-1',
            createdAt: seededAt,
          ),
        );
    await rewindToSchemaOne(database);
    await database.close();

    database = AppDatabase(NativeDatabase(file));
    addTearDown(database.close);

    final drafts = await database.select(database.draftIndex).get();
    expect(drafts.single.designId, 'dsg_legacy');
    expect(drafts.single.revision, 7);
    expect(drafts.single.title, 'Печать 10×15');

    final actions = await database.select(database.pendingActions).get();
    expect(actions.single.idempotencyKey, 'key-1');

    expect(await database.select(database.appSettings).get(), isEmpty);
    await SettingsRepository(database)
        .write(SettingsRepository.localeKey, 'be');
    expect(
      await SettingsRepository(database).read(SettingsRepository.localeKey),
      'be',
    );
    expect((await database.select(database.draftIndex).get()), hasLength(1));
  });

  test('свежая база сразу второй версии: обе таблицы на месте', () async {
    final database = AppDatabase(NativeDatabase(file));
    addTearDown(database.close);

    expect(database.schemaVersion, 2);
    expect(await database.select(database.appSettings).get(), isEmpty);
    expect(await database.select(database.draftIndex).get(), isEmpty);
  });
}
