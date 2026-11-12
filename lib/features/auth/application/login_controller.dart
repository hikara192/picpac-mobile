import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/auth_repository.dart';
import '../../../core/session/session_controller.dart';

enum LoginMode {
  password,

  code,
}

final class LoginState {
  const LoginState({
    this.mode = LoginMode.password,
    this.busy = false,
    this.codeRequested = false,
    this.failure,
  });

  final LoginMode mode;

  final bool busy;

  final bool codeRequested;

  final Failure? failure;

  LoginState copyWith({
    LoginMode? mode,
    bool? busy,
    bool? codeRequested,
    Failure? failure,
    bool clearFailure = false,
  }) => LoginState(
    mode: mode ?? this.mode,
    busy: busy ?? this.busy,
    codeRequested: codeRequested ?? this.codeRequested,
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}

final class LoginOutcome {
  const LoginOutcome.signedIn(AuthSession this.session) : failure = null;

  const LoginOutcome.failed(Failure this.failure) : session = null;

  final AuthSession? session;

  final Failure? failure;

  bool get isSignedIn => session != null;
}

final class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  void setMode(LoginMode mode) {
    state = state.copyWith(
      mode: mode,
      clearFailure: true,
      codeRequested: mode == LoginMode.code ? state.codeRequested : false,
    );
  }

  void requestCode() {
    state = state.copyWith(codeRequested: true, clearFailure: true);
  }

  Future<LoginOutcome> submit({
    required String email,
    required String password,
    required String code,
  }) async {
    if (state.busy) return LoginOutcome.failed(_busyFailure);
    state = state.copyWith(busy: true, clearFailure: true);
    final repository = ref.read(authRepositoryProvider);
    final Result<AuthSession> result = state.mode == LoginMode.password
        ? await repository.signIn(email: email, password: password)
        : await repository.verifyCode(
            challengeId: AuthRepository.demoChallengeId,
            code: code,
          );
    if (!ref.mounted) {
      return result.fold(ok: LoginOutcome.signedIn, err: LoginOutcome.failed);
    }
    switch (result) {
      case Ok<AuthSession>(:final value):
        await ref.read(sessionControllerProvider.notifier).signedIn(value);
        ref.invalidate(currentCustomerProvider);
        if (!ref.mounted) return LoginOutcome.signedIn(value);
        state = const LoginState();
        return LoginOutcome.signedIn(value);
      case Err<AuthSession>(:final error):
        state = state.copyWith(busy: false, failure: error);
        return LoginOutcome.failed(error);
    }
  }

  Future<LoginOutcome> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (state.busy) return LoginOutcome.failed(_busyFailure);
    state = state.copyWith(busy: true, clearFailure: true);
    final result = await ref
        .read(authRepositoryProvider)
        .register(name: name, email: email, password: password);
    if (!ref.mounted) {
      return result.fold(ok: LoginOutcome.signedIn, err: LoginOutcome.failed);
    }
    switch (result) {
      case Ok<AuthSession>(:final value):
        await ref.read(sessionControllerProvider.notifier).signedIn(value);
        ref.invalidate(currentCustomerProvider);
        if (!ref.mounted) return LoginOutcome.signedIn(value);
        state = const LoginState();
        return LoginOutcome.signedIn(value);
      case Err<AuthSession>(:final error):
        state = state.copyWith(busy: false, failure: error);
        return LoginOutcome.failed(error);
    }
  }

  static const ApiFailure _busyFailure = ApiFailure(
    code: ApiErrorCode.validationFailed,
    message: 'a sign-in attempt is already running',
  );
}

final loginControllerProvider = NotifierProvider<LoginController, LoginState>(
  LoginController.new,
);
