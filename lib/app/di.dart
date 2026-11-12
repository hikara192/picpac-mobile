import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/misc.dart' show Override;

import 'package:api_contract/api_contract.dart';

import '../core/analytics.dart';
import '../core/app_logger.dart';
import '../core/clock.dart';
import '../core/orders/demo_controls.dart';
import '../core/storage/app_database.dart';
import '../core/storage/draft_store.dart';
import '../network/token_store.dart';
import 'env.dart';

final Provider<AppEnv> envProvider = Provider<AppEnv>((ref) => AppEnv.current);

final Provider<AppLogger> loggerProvider = Provider<AppLogger>(
  (ref) => const AppLogger(),
);

final Provider<Analytics> analyticsProvider = Provider<Analytics>((ref) {
  final env = ref.watch(envProvider);
  return env.flavor == AppFlavor.prod
      ? const NoopAnalytics()
      : DebugAnalytics(ref.watch(loggerProvider));
});

final Provider<Clock> clockProvider = Provider<Clock>(
  (ref) => const SystemClock(),
);

final Provider<TokenStore> tokenStoreProvider = Provider<TokenStore>(
  (ref) => throw StateError('TokenStore must be overridden at bootstrap'),
);

final Provider<ApiPort> apiPortProvider = Provider<ApiPort>(
  (ref) => throw StateError('ApiPort must be overridden at bootstrap'),
);

final Provider<AppDatabase> databaseProvider = Provider<AppDatabase>(
  (ref) => throw StateError('AppDatabase must be overridden at bootstrap'),
);

final Provider<DraftStore> draftStoreProvider = Provider<DraftStore>((ref) {
  final database = ref.watch(databaseProvider);
  final store = DraftStore(database: database, rootDirectory: defaultDraftRoot);
  ref.onDispose(store.dispose);
  return store;
});

List<Override> appOverrides({
  required AppEnv env,
  required ApiPort api,
  required TokenStore tokens,
  required AppDatabase database,
  Clock clock = const SystemClock(),
  String? apiBaseUrl,
}) => <Override>[
  envProvider.overrideWithValue(env),
  apiPortProvider.overrideWithValue(api),
  tokenStoreProvider.overrideWithValue(tokens),
  databaseProvider.overrideWithValue(database),
  clockProvider.overrideWithValue(clock),
  demoControlsConfigProvider.overrideWithValue(
    apiBaseUrl == null ? null : DemoControlsConfig(baseUrl: apiBaseUrl),
  ),
];
