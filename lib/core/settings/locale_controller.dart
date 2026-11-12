import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di.dart' show databaseProvider;
import 'settings_repository.dart';

enum AppLocaleChoice {
  system(null, 'system'),

  ru(Locale('ru'), 'ru'),

  be(Locale('be'), 'be');

  const AppLocaleChoice(this.locale, this.storageValue);

  final Locale? locale;

  final String storageValue;

  static AppLocaleChoice fromStorage(String? value) =>
      AppLocaleChoice.values.firstWhere(
        (AppLocaleChoice choice) => choice.storageValue == value,
        orElse: () => AppLocaleChoice.system,
      );

  static AppLocaleChoice fromLocale(Locale? locale) =>
      switch (locale?.languageCode) {
        'ru' => AppLocaleChoice.ru,
        'be' => AppLocaleChoice.be,
        _ => AppLocaleChoice.system,
      };
}

Locale resolveAppLocale(Locale? deviceLocale, Iterable<Locale> supported) {
  if (deviceLocale != null) {
    for (final Locale locale in supported) {
      if (locale.languageCode == deviceLocale.languageCode) return locale;
    }
  }
  return const Locale('ru');
}

final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
      (Ref ref) => SettingsRepository(ref.watch(databaseProvider)),
    );

final NotifierProvider<LocaleController, Locale?> localeControllerProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);

class LocaleController extends Notifier<Locale?> {
  Future<void>? _restoring;

  @override
  Locale? build() {
    _restoring = _restore();
    return null;
  }

  AppLocaleChoice get choice => AppLocaleChoice.fromLocale(state);

  Future<void> ensureRestored() => _restoring ??= _restore();

  Future<void> select(AppLocaleChoice choice) async {
    state = choice.locale;
    try {
      final repository = ref.read(settingsRepositoryProvider);
      if (choice == AppLocaleChoice.system) {
        await repository.remove(SettingsRepository.localeKey);
      } else {
        await repository.write(
          SettingsRepository.localeKey,
          choice.storageValue,
        );
      }
    } on Object {
    }
  }

  Future<void> _restore() async {
    String? stored;
    try {
      stored = await ref
          .read(settingsRepositoryProvider)
          .read(SettingsRepository.localeKey);
    } on Object {
      return;
    }
    final locale = AppLocaleChoice.fromStorage(stored).locale;
    if (locale == null || !ref.mounted) return;
    state = locale;
  }
}
