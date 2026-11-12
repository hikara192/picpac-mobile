import 'package:api_contract/api_contract.dart';

import 'ai_context.dart';
import 'ai_port.dart';

final class AiRequest {
  const AiRequest({required this.context, required this.localOnly});

  final AiContext context;

  final bool localOnly;
}

final class AiRouter {
  const AiRouter({
    required this.remote,
    required this.local,
    required this.enabled,
  });

  final AiPort remote;

  final AiPort local;

  final bool enabled;

  Future<Result<AiSuggestion>> suggest(AiRequest request) async {
    if (request.localOnly) {
      final quick = await local.propose(request.context);
      return quick.map(
        (patch) => AiSuggestion(patch: patch, capability: local.capability),
      );
    }
    if (!enabled) {
      return Err<AiSuggestion>(
        const ApiFailure(
          code: ApiErrorCode.aiDisabled,
          message: 'the AI contour is disabled in this build',
        ),
      );
    }
    final remoteResult = await remote.propose(request.context);
    switch (remoteResult) {
      case Ok<DesignPatch>(:final value):
        return Ok<AiSuggestion>(
          AiSuggestion(patch: value, capability: remote.capability),
        );
      case Err<DesignPatch>(:final error):
        if (!_isNetworkFailure(error)) return Err<AiSuggestion>(error);
        final fallback = await local.propose(request.context);
        return switch (fallback) {
          Ok<DesignPatch>(:final value) => Ok<AiSuggestion>(
            AiSuggestion(patch: value, capability: local.capability),
          ),
          Err<DesignPatch>() => Err<AiSuggestion>(error),
        };
    }
  }

  static bool _isNetworkFailure(Failure failure) =>
      failure.code == ApiErrorCode.networkUnavailable ||
      failure.code == ApiErrorCode.timeout;
}
