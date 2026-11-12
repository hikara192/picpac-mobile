import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mock_server/mock_server.dart' as mock;

import '../core/app_logger.dart';
import '../core/settings/locale_controller.dart' show resolveAppLocale;
import '../core/storage/app_database.dart';
import '../l10n/app_localizations.dart';
import '../network/http_api.dart';
import '../network/token_store.dart';
import 'app.dart';
import 'di.dart';
import 'env.dart';

final class AppDependencies {
  const AppDependencies({
    required this.env,
    required this.baseUrl,
    required this.tokens,
    required this.database,
    required this.api,
    this.embeddedServer,
  });

  final AppEnv env;
  final String baseUrl;
  final TokenStore tokens;
  final AppDatabase database;
  final HttpApi api;

  final HttpServer? embeddedServer;

  Future<void> dispose() async {
    await database.close();
    await embeddedServer?.close(force: true);
  }
}

Future<AppDependencies> bootstrap({
  AppEnv? env,
  AppLogger? logger,
  SecureKeyValueStore? secureStore,
  AppDatabase? database,
}) async {
  final resolvedEnv = env ?? AppEnv.current;
  final validation = resolvedEnv.validate();
  if (validation != null) {
    throw StateError(validation);
  }

  final tokens = TokenStore(secureStore ?? const PlatformSecureStore());
  await tokens.restore();

  final localDatabase = database ?? AppDatabase.open();

  HttpServer? embedded;
  String baseUrl;
  if (resolvedEnv.usesExternalServer) {
    baseUrl = resolvedEnv.apiBaseUrl!;
  } else {
    embedded = await mock.startMockServer(
      port: 0,
      logSink: kDebugMode ? (line) => logger?.debug('mock.$line') : null,
    );
    baseUrl = 'http://${embedded.address.host}:${embedded.port}';
  }

  final api = HttpApi(
    baseUrl: baseUrl,
    tokens: tokens,
    logger: logger ?? const AppLogger(),
  );

  return AppDependencies(
    env: resolvedEnv,
    baseUrl: baseUrl,
    tokens: tokens,
    database: localDatabase,
    api: api,
    embeddedServer: embedded,
  );
}

Future<void> runPicPac() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? failure;
  AppDependencies? dependencies;
  try {
    dependencies = await bootstrap();
  } on Object catch (error) {
    failure = error;
  }
  runApp(PicPacBootstrap(dependencies: dependencies, startupFailure: failure));
}

class PicPacBootstrap extends StatefulWidget {
  const PicPacBootstrap({this.dependencies, this.startupFailure, super.key});

  final AppDependencies? dependencies;
  final Object? startupFailure;

  @override
  State<PicPacBootstrap> createState() => _PicPacBootstrapState();
}

class _PicPacBootstrapState extends State<PicPacBootstrap> {
  late AppDependencies? _dependencies = widget.dependencies;
  late Object? _failure = widget.startupFailure;
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    try {
      final dependencies = await bootstrap();
      setState(() {
        _dependencies = dependencies;
        _failure = null;
      });
    } on Object catch (error) {
      setState(() => _failure = error);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = _dependencies;
    if (dependencies == null) {
      return StartupErrorApp(
        error: _failure,
        retrying: _retrying,
        onRetry: _retry,
      );
    }
    return ProviderScope(
      overrides: appOverrides(
        env: dependencies.env,
        api: dependencies.api,
        tokens: dependencies.tokens,
        database: dependencies.database,
        apiBaseUrl: dependencies.baseUrl,
      ),
      child: PicPacApp(env: dependencies.env),
    );
  }
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({
    required this.error,
    required this.retrying,
    required this.onRetry,
    super.key,
  });

  final Object? error;
  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: resolveAppLocale,
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      l10n.startupTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$error',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF7C807F),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: retrying ? null : onRetry,
                      child: Text(
                        retrying ? l10n.startupRetrying : l10n.actionRetry,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
