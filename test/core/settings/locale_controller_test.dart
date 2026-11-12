import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:picpac_mobile/app/di.dart';
import 'package:picpac_mobile/core/settings/locale_controller.dart';
import 'package:picpac_mobile/core/settings/settings_repository.dart';
import 'package:picpac_mobile/core/storage/app_database.dart';
import 'package:picpac_mobile/l10n/app_localizations.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;

  ProviderContainer createContainer() => ProviderContainer(
    overrides: <Override>[databaseProvider.overrideWithValue(database)],
  );

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    container = createContainer();
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  group('resolveAppLocale', () {
    final supported = AppLocalizations.supportedLocales;

    test('белорусская система → be', () {
      expect(
        resolveAppLocale(const Locale('be'), supported).languageCode,
        'be',
      );
    });

    test('русская система → ru', () {
      expect(
        resolveAppLocale(const Locale('ru'), supported).languageCode,
        'ru',
      );
    });

    test('любой другой язык → ru, а не первый из supportedLocales', () {
      expect(
        resolveAppLocale(const Locale('pl'), supported).languageCode,
        'ru',
      );
      expect(resolveAppLocale(null, supported).languageCode, 'ru');
    });

    test('регион не мешает: ru_BY → ru', () {
      expect(
        resolveAppLocale(const Locale('ru', 'BY'), supported).languageCode,
        'ru',
      );
    });
  });

  group('LocaleController', () {
    test('по умолчанию — системный язык и никакой строки в базе', () async {
      final controller = container.read(localeControllerProvider.notifier);
      expect(container.read(localeControllerProvider), isNull);
      await controller.ensureRestored();
      expect(container.read(localeControllerProvider), isNull);
      expect(controller.choice, AppLocaleChoice.system);
      expect(
        await SettingsRepository(database).read(SettingsRepository.localeKey),
        isNull,
      );
    });

    test('выбор применяется сразу и сохраняется', () async {
      final controller = container.read(localeControllerProvider.notifier);

      final switching = controller.select(AppLocaleChoice.be);
      expect(container.read(localeControllerProvider), const Locale('be'));
      await switching;

      expect(
        await SettingsRepository(database).read(SettingsRepository.localeKey),
        'be',
      );
    });

    test('пересоздание контейнера возвращает ту же локаль', () async {
      await container
          .read(localeControllerProvider.notifier)
          .select(AppLocaleChoice.be);
      container.dispose();

      container = createContainer();
      expect(
        container.read(localeControllerProvider),
        isNull,
        reason: 'до чтения базы состояние ещё не восстановлено',
      );
      await container.read(localeControllerProvider.notifier).ensureRestored();
      expect(container.read(localeControllerProvider), const Locale('be'));
    });

    test('«системный» удаляет строку, а не пишет слово system', () async {
      final controller = container.read(localeControllerProvider.notifier);
      await controller.select(AppLocaleChoice.ru);
      await controller.select(AppLocaleChoice.system);

      expect(container.read(localeControllerProvider), isNull);
      expect(
        await SettingsRepository(database).read(SettingsRepository.localeKey),
        isNull,
      );
    });

    test('неизвестное значение в базе не ломает запуск', () async {
      await SettingsRepository(database)
          .write(SettingsRepository.localeKey, 'kk');
      container.dispose();

      container = createContainer();
      await container.read(localeControllerProvider.notifier).ensureRestored();
      expect(container.read(localeControllerProvider), isNull);
      expect(
        container.read(localeControllerProvider.notifier).choice,
        AppLocaleChoice.system,
      );
    });
  });

  group('SettingsRepository', () {
    test('повторная запись не дублирует строку', () async {
      final repository = SettingsRepository(database);
      await repository.write(SettingsRepository.localeKey, 'ru');
      await repository.write(SettingsRepository.localeKey, 'be');
      final rows = await database.select(database.appSettings).get();
      expect(rows, hasLength(1));
      expect(rows.single.value, 'be');
    });

    test('разные ключи не мешают друг другу', () async {
      final repository = SettingsRepository(database);
      await repository.write(SettingsRepository.localeKey, 'be');
      await repository.write('experiment', 'on');
      expect(await repository.read(SettingsRepository.localeKey), 'be');
      expect(await repository.read('experiment'), 'on');
      await repository.remove('experiment');
      expect(await repository.read('experiment'), isNull);
      expect(await repository.read(SettingsRepository.localeKey), 'be');
    });
  });
}
