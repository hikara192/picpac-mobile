import 'dart:async';

import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di.dart';
import '../orders/cart_repository.dart';
import 'auth_repository.dart';
import 'guest_work.dart';
import 'session_service.dart';
import 'session_view.dart';

final class SessionController extends Notifier<SessionView> {
  @override
  SessionView build() {
    final tokens = ref.watch(tokenStoreProvider);
    ref.watch(sessionServiceProvider).onUnauthorized = _onUnauthorized;
    return SessionView(session: tokens.session);
  }

  void _onUnauthorized() {
    unawaited(sessionExpired());
  }

  Future<void> signedIn(AuthSession session) async {
    await ref.read(tokenStoreProvider).save(session);
    ref.read(cartRepositoryProvider).clearCache();
    ref.read(guestWorkProvider.notifier).signedIn();
    if (!ref.mounted) return;
    state = SessionView(
      session: session,
      customer: session.customer,
      expiryCount: state.expiryCount,
    );
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    ref.read(cartRepositoryProvider).clearCache();
    if (!ref.mounted) return;
    await _renewGuest();
  }

  Future<void> accountDeleted() async {
    ref.read(guestWorkProvider.notifier).clear();
    ref.read(cartRepositoryProvider).clearCache();
    if (!ref.mounted) return;
    await _renewGuest();
  }

  Future<void> sessionExpired() async {
    final tokens = ref.read(tokenStoreProvider);
    if (!tokens.isAuthenticated) return;
    final expiryCount = state.expiryCount + 1;
    await tokens.clear();
    ref.read(cartRepositoryProvider).clearCache();
    if (!ref.mounted) return;
    state = SessionView(expiryCount: expiryCount);
  }

  Future<void> _renewGuest() async {
    await ref.read(sessionServiceProvider).ensureGuest();
    if (!ref.mounted) return;
    state = SessionView(
      session: ref.read(tokenStoreProvider).session,
      expiryCount: state.expiryCount,
    );
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionView>(SessionController.new);

final class CurrentCustomerController extends AsyncNotifier<Customer?> {
  @override
  Future<Customer?> build() async {
    final session = ref.watch(sessionControllerProvider);
    if (!session.isAccount) return null;
    final result = await ref.watch(apiPortProvider).currentCustomer();
    switch (result) {
      case Ok<Customer>(:final value):
        return value;
      case Err<Customer>(:final error):
        if (error.code == ApiErrorCode.unauthorized) {
          unawaited(
            ref.read(sessionControllerProvider.notifier).sessionExpired(),
          );
        }
        throw error;
    }
  }

  Future<void> reload() async {
    state = const AsyncLoading<Customer?>();
    state = await AsyncValue.guard(() => _load());
  }

  Future<Customer?> _load() async {
    final result = await ref.read(apiPortProvider).currentCustomer();
    return result.fold(
      ok: (customer) => customer,
      err: (failure) => throw failure,
    );
  }
}

final currentCustomerProvider =
    AsyncNotifierProvider<CurrentCustomerController, Customer?>(
      CurrentCustomerController.new,
      retry: (retryCount, error) => null,
    );

Future<void> signOutIfUnauthorized(Ref ref, Failure failure) async {
  if (failure.code != ApiErrorCode.unauthorized) return;
  final tokens = ref.read(tokenStoreProvider);
  if (!tokens.isAuthenticated) return;
  await ref.read(sessionControllerProvider.notifier).sessionExpired();
}
