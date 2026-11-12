import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di.dart';
import '../../network/token_store.dart';
import '../offline/pending_actions.dart';
import '../orders/order_cache.dart';
import '../storage/draft_store.dart';

final class AuthRepository {
  AuthRepository({
    required this._api,
    required this._tokens,
    required this._drafts,
    required this._orders,
    required this._pending,
  });

  static const String demoChallengeId = 'challenge_demo';

  static const String demoCode = '0000';

  final ApiPort _api;
  final TokenStore _tokens;
  final DraftStore _drafts;
  final OrderCache _orders;
  final PendingActionsStore _pending;

  Future<Result<AuthSession>> register({
    required String name,
    required String email,
    required String password,
  }) => _api.register(
    RegisterRequest(
      name: name.trim(),
      email: email.trim(),
      password: password,
      locale: 'ru',
    ),
  );

  Future<Result<AuthSession>> signIn({
    required String email,
    required String password,
  }) async {
    final result = await _api.login(
      LoginRequest(email: email.trim(), password: password, locale: 'ru'),
    );
    if (result case Ok<AuthSession>(:final value)) await _tokens.save(value);
    return result;
  }

  Future<Result<AuthSession>> verifyCode({
    required String challengeId,
    required String code,
  }) async {
    final result = await _api.verifyCode(
      challengeId: challengeId,
      code: code.trim(),
    );
    if (result case Ok<AuthSession>(:final value)) await _tokens.save(value);
    return result;
  }

  Future<Result<Customer>> customer() => _api.currentCustomer();

  Future<Result<void>> deleteAccount() async {
    final result = await _api.deleteAccount();
    if (result case Ok<void>()) {
      await _tokens.clear();
      await _drafts.deleteAll();
      await _orders.clear();
      await _pending.clear();
    }
    return result;
  }

  Future<void> signOut() async {
    await _tokens.clear();
    await _orders.clear();
    await _pending.clear();
  }
}

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>(
      (ref) => AuthRepository(
        api: ref.watch(apiPortProvider),
        tokens: ref.watch(tokenStoreProvider),
        drafts: ref.watch(draftStoreProvider),
        orders: ref.watch(orderCacheProvider),
        pending: ref.watch(pendingActionsStoreProvider),
      ),
    );
