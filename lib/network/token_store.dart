import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:api_contract/api_contract.dart';

abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

final class PlatformSecureStore implements SecureKeyValueStore {
  const PlatformSecureStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

final class InMemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

final class TokenStore {
  TokenStore(this._storage);

  static const String _tokenKey = 'picpac.session.token';
  static const String _refreshKey = 'picpac.session.refresh';
  static const String _roleKey = 'picpac.session.role';

  final SecureKeyValueStore _storage;

  AuthSession? _cached;

  AuthSession? get session => _cached;

  UserRole get role => _cached?.role ?? UserRole.guest;

  bool get isAuthenticated => _cached?.token != null;

  Future<void> restore() async {
    final token = await _storage.read(_tokenKey);
    if (token == null || token.isEmpty) return;
    final refresh = await _storage.read(_refreshKey);
    final role = UserRole.fromWire(await _storage.read(_roleKey));
    _cached = AuthSession(
      token: token,
      refreshToken: refresh,
      role: role,
      customerId: null,
    );
  }

  Future<AuthSession> save(AuthSession session) async {
    _cached = session;
    await _storage.write(_tokenKey, session.token);
    final refresh = session.refreshToken;
    if (refresh == null) {
      await _storage.delete(_refreshKey);
    } else {
      await _storage.write(_refreshKey, refresh);
    }
    await _storage.write(_roleKey, session.role.name);
    return session;
  }

  Future<void> clear() async {
    _cached = null;
    await _storage.delete(_tokenKey);
    await _storage.delete(_refreshKey);
    await _storage.delete(_roleKey);
  }
}
