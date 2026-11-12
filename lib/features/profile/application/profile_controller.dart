import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/offline_queue.dart';
import '../../../core/orders/order_cache.dart';
import '../../../core/session/auth_repository.dart';
import '../../../core/session/session_controller.dart';
import '../../../app/di.dart';

final class AccountActionState {
  const AccountActionState({this.busy = false, this.failure});

  final bool busy;

  final Failure? failure;
}

final class AccountActions extends Notifier<AccountActionState> {
  @override
  AccountActionState build() => const AccountActionState();

  Future<Result<void>> deleteAccount() async {
    if (state.busy) return Err<void>(_busy);
    state = const AccountActionState(busy: true);
    final result = await ref.read(authRepositoryProvider).deleteAccount();
    if (!ref.mounted) return result;
    switch (result) {
      case Ok<void>():
        state = const AccountActionState();
        ref.invalidate(currentCustomerProvider);
        ref.invalidate(pendingActionsControllerProvider);
        await ref.read(sessionControllerProvider.notifier).accountDeleted();
        return const Ok<void>(null);
      case Err<void>(:final error):
        await signOutIfUnauthorized(ref, error);
        if (ref.mounted) state = AccountActionState(failure: error);
        return result;
    }
  }

  Future<int?> deleteTestData() async {
    if (state.busy) return null;
    state = const AccountActionState(busy: true);
    final drafts = ref.read(draftStoreProvider);
    final count = (await drafts.list()).length;
    await drafts.deleteAll();
    await ref.read(orderCacheProvider).clear();
    await ref.read(pendingActionsControllerProvider.notifier).clear();
    if (!ref.mounted) return count;
    state = const AccountActionState();
    return count;
  }

  Future<void> signOut() async {
    if (state.busy) return;
    state = const AccountActionState(busy: true);
    await ref.read(sessionControllerProvider.notifier).signOut();
    if (!ref.mounted) return;
    state = const AccountActionState();
    ref.invalidate(currentCustomerProvider);
    ref.invalidate(pendingActionsControllerProvider);
  }

  static const ApiFailure _busy = ApiFailure(
    code: ApiErrorCode.validationFailed,
    message: 'another account action is already running',
  );
}

final accountActionsProvider =
    NotifierProvider<AccountActions, AccountActionState>(AccountActions.new);
