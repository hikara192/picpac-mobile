import 'package:api_contract/api_contract.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:picpac_mobile/app/app.dart';
import 'package:picpac_mobile/app/di.dart';
import 'package:picpac_mobile/app/env.dart';
import 'package:picpac_mobile/app/router.dart';
import 'package:picpac_mobile/core/clock.dart';
import 'package:picpac_mobile/core/settings/locale_controller.dart';
import 'package:picpac_mobile/core/settings/settings_repository.dart';
import 'package:picpac_mobile/core/storage/app_database.dart';
import 'package:picpac_mobile/features/profile/presentation/profile_page.dart';
import 'package:picpac_mobile/l10n/app_localizations.dart';
import 'package:picpac_mobile/network/token_store.dart';

import '../../features/support/fixtures.dart';
import '../../features/support/funnel_harness.dart';

void main() {
  setUpAll(registerFunnelFallbacks);

  Future<void> settle(WidgetTester tester, {int frames = 8}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  Customer customerFixture() => Customer(
    id: 'cus_demo',
    createdAt: testNow,
    name: 'Тестовый клиент',
    email: 'customer@picpac.test',
    phoneMasked: '+375 ** *** 12 34',
  );

  testWidgets('выбор «Беларуская» меняет экран сразу и сохраняется', (
    tester,
  ) async {
    useTallViewport(tester);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final api = FakeApi();
    final tokens = TokenStore(InMemorySecureStore());
    await tokens.save(
      AuthSession(token: 'test-token', role: UserRole.customer),
    );
    when(() => api.currentCustomer())
        .thenAnswer((_) async => Ok<Customer>(customerFixture()));
    const env = AppEnv(apiMode: ApiMode.embedded, flavor: AppFlavor.dev);

    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(
          env: env,
          api: api,
          tokens: tokens,
          database: database,
          clock: FixedClock(testNow),
        ),
        child: const PicPacApp(env: env),
      ),
    );
    await settle(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    container.read(routerProvider).go(AppRoutes.profile);
    await settle(tester);

    expect(find.widgetWithText(AppBar, 'Профиль'), findsOneWidget);
    expect(find.text('Заказы'), findsOneWidget);
    expect(find.text('Мова'), findsNothing);

    final option = find.text('Беларуская');
    await tester.ensureVisible(option);
    await settle(tester);
    await tester.tap(option);
    await settle(tester);

    expect(find.widgetWithText(AppBar, 'Профіль'), findsOneWidget);
    expect(find.text('Замовы'), findsOneWidget);
    expect(find.text('Заказы'), findsNothing);
    expect(find.text('Мова'), findsOneWidget);

    final group = tester.widget<RadioGroup<AppLocaleChoice>>(
      find.byType(RadioGroup<AppLocaleChoice>),
    );
    expect(group.groupValue, AppLocaleChoice.be);

    expect(
      await SettingsRepository(database).read(SettingsRepository.localeKey),
      'be',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    final restarted = ProviderContainer(
      overrides: <Override>[databaseProvider.overrideWithValue(database)],
    );
    addTearDown(restarted.dispose);
    expect(restarted.read(localeControllerProvider), isNull);
    await restarted.read(localeControllerProvider.notifier).ensureRestored();
    expect(restarted.read(localeControllerProvider), const Locale('be'));
  });

  testWidgets('гость тоже видит блок «Язык»', (tester) async {
    useTallViewport(tester);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final api = FakeApi();
    final tokens = TokenStore(InMemorySecureStore());

    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(
          env: const AppEnv(apiMode: ApiMode.embedded, flavor: AppFlavor.dev),
          api: api,
          tokens: tokens,
          database: database,
          clock: FixedClock(testNow),
        ),
        child: MaterialApp(
          locale: const Locale('ru'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const ProfilePage(),
        ),
      ),
    );
    await settle(tester);

    expect(find.text('Вы не вошли'), findsOneWidget);
    expect(find.text('Язык'), findsOneWidget);
    expect(find.text('Системный'), findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);
    expect(find.text('Беларуская'), findsOneWidget);
  });
}
