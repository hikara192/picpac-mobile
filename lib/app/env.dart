library;

enum ApiMode {
  embedded,

  http,
}

enum AppFlavor { dev, staging, prod }

final class AppEnv {
  const AppEnv({
    required this.apiMode,
    required this.flavor,
    this.apiBaseUrl,
    this.aiEnabled = false,
  });

  static final AppEnv current = AppEnv(
    apiMode: _apiMode,
    flavor: _flavor,
    apiBaseUrl: _apiBaseUrl,
    aiEnabled: _aiEnabled,
  );

  static const String _rawApiMode = String.fromEnvironment(
    'API_MODE',
    defaultValue: 'embedded',
  );
  static const String _rawFlavor = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );
  static const String _rawBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const bool _aiEnabled = bool.fromEnvironment('AI_ENABLED');

  static const ApiMode _apiMode = _rawApiMode == 'http'
      ? ApiMode.http
      : ApiMode.embedded;
  static final AppFlavor _flavor = switch (_rawFlavor) {
    'prod' => AppFlavor.prod,
    'staging' => AppFlavor.staging,
    _ => AppFlavor.dev,
  };
  static final String? _apiBaseUrl = _rawBaseUrl == '' ? null : _rawBaseUrl;

  final ApiMode apiMode;
  final AppFlavor flavor;

  final String? apiBaseUrl;

  final bool aiEnabled;

  bool get usesExternalServer => apiMode == ApiMode.http;

  String? validate() {
    if (apiMode == ApiMode.embedded && flavor != AppFlavor.dev) {
      return 'embedded mock is allowed in dev only';
    }
    if (apiMode == ApiMode.http) {
      final url = apiBaseUrl;
      if (url == null) return 'API_BASE_URL is required when API_MODE=http';
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        return 'API_BASE_URL is not a valid absolute URL';
      }
      if (uri.scheme == 'http' && flavor != AppFlavor.dev) {
        return 'plain HTTP is allowed in dev only';
      }
    }
    return null;
  }
}
