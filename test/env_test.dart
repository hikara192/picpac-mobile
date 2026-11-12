import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/app/env.dart';

void main() {
  group('AppEnv', () {
    test('embedded mode needs no base URL', () {
      const env = AppEnv(apiMode: ApiMode.embedded, flavor: AppFlavor.dev);
      expect(env.validate(), isNull);
      expect(env.usesExternalServer, isFalse);
    });

    test('http mode requires a base URL', () {
      const env = AppEnv(apiMode: ApiMode.http, flavor: AppFlavor.dev);
      expect(env.validate(), contains('API_BASE_URL'));
    });

    test('rejects a relative base URL', () {
      const env = AppEnv(
        apiMode: ApiMode.http,
        flavor: AppFlavor.dev,
        apiBaseUrl: 'not a url',
      );
      expect(env.validate(), isNotNull);
    });

    test('plain HTTP is allowed in dev only', () {
      const dev = AppEnv(
        apiMode: ApiMode.http,
        flavor: AppFlavor.dev,
        apiBaseUrl: 'http://127.0.0.1:8080',
      );
      const prod = AppEnv(
        apiMode: ApiMode.http,
        flavor: AppFlavor.prod,
        apiBaseUrl: 'http://api.picpac.by',
      );
      expect(dev.validate(), isNull);
      expect(prod.validate(), contains('HTTP'));
    });

    test('embedded mock is rejected outside dev', () {
      const env = AppEnv(apiMode: ApiMode.embedded, flavor: AppFlavor.prod);
      expect(env.validate(), contains('dev only'));
    });

    test('AI contour is off by default', () {
      const env = AppEnv(apiMode: ApiMode.embedded, flavor: AppFlavor.dev);
      expect(env.aiEnabled, isFalse);
    });
  });
}
