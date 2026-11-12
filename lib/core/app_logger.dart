import 'dart:developer' as developer;

enum LogLevel { debug, info, warning, error }

final class AppLogger {
  const AppLogger({this.minLevel = LogLevel.info, this.enabled = true});

  final LogLevel minLevel;

  final bool enabled;

  void log(
    LogLevel level,
    String event, {
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    if (!enabled || level.index < minLevel.index) return;
    developer.log(
      event,
      name: 'picpac.${level.name}',
      error: fields.isEmpty ? null : fields,
    );
  }

  void debug(String event, [Map<String, Object?> fields = const {}]) =>
      log(LogLevel.debug, event, fields: fields);

  void info(String event, [Map<String, Object?> fields = const {}]) =>
      log(LogLevel.info, event, fields: fields);

  void warning(String event, [Map<String, Object?> fields = const {}]) =>
      log(LogLevel.warning, event, fields: fields);

  void error(
    String event, [
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  ]) => developer.log(
    event,
    name: 'picpac.error',
    error: error,
    stackTrace: stackTrace,
  );
}
