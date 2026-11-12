import 'package:api_contract/api_contract.dart';

Duration? noProviderRetry(int retryCount, Object error) => null;

Failure failureOr(Object error) => switch (error) {
  Failure() => error,
  _ => ApiFailure(code: ApiErrorCode.serverError, message: error.toString()),
};
