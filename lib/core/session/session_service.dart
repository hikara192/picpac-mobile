import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di.dart';
import '../../network/token_store.dart';

final class SessionService {
  SessionService({required this._api, required this._tokens});

  final ApiPort _api;
  final TokenStore _tokens;

  void Function()? onUnauthorized;

  Future<void>? _guestFlight;

  bool get isAuthenticated => _tokens.isAuthenticated;

  UserRole get role => _tokens.role;

  bool get canPlaceOrders => _tokens.role == UserRole.customer;

  Future<void> ensureGuest() {
    if (_tokens.isAuthenticated) return Future<void>.value();
    return _guestFlight ??= _createGuest().whenComplete(() {
      _guestFlight = null;
    });
  }

  Future<Result<T>> ensureSession<T>(
    Future<Result<T>> Function() action,
  ) async {
    final hadSession = _tokens.isAuthenticated;
    if (!hadSession) await ensureGuest();
    final first = await action();
    final failure = first.failureOrNull;
    if (failure == null) return first;
    final renewable =
        failure.code == ApiErrorCode.unauthorized &&
        (hadSession ? _tokens.role == UserRole.guest : false);
    if (!renewable) {
      if (failure.code == ApiErrorCode.unauthorized &&
          _tokens.role != UserRole.guest) {
        onUnauthorized?.call();
      }
      return first;
    }
    await _tokens.clear();
    await ensureGuest();
    return action();
  }

  Future<Result<T>> ensurePublic<T>(Future<Result<T>> Function() action) async {
    if (!_tokens.isAuthenticated) await ensureGuest();
    final first = await action();
    final failure = first.failureOrNull;
    if (failure == null || failure.code != ApiErrorCode.unauthorized) {
      return first;
    }
    final wasAccount = _tokens.role != UserRole.guest;
    if (wasAccount) onUnauthorized?.call();
    await _tokens.clear();
    await ensureGuest();
    return action();
  }

  Future<void> _createGuest() async {
    final result = await _api.createAnonymousSession(
      const AnonymousSessionRequest(locale: 'ru'),
    );
    if (result case Ok<AuthSession>(:final value)) {
      await _tokens.save(value);
    }
  }
}

final Provider<SessionService> sessionServiceProvider =
    Provider<SessionService>(
      (ref) => SessionService(
        api: ref.watch(apiPortProvider),
        tokens: ref.watch(tokenStoreProvider),
      ),
    );
