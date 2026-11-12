import 'dart:async';

import 'package:api_contract/api_contract.dart';

import 'ai_context.dart';
import 'ai_port.dart';

final class HttpAi implements AiPort {
  HttpAi({
    required this.api,
    this.maxOps = kMaxPatchOperations,
    this.deadline = defaultDeadline,
  });

  static const Duration defaultDeadline = Duration(seconds: 20);

  final ApiPort api;

  final int maxOps;

  final Duration deadline;

  @override
  AiCapability get capability => AiCapability.remote;

  @override
  Future<Result<DesignPatch>> propose(AiContext context) async {
    final bounded = AiContext(
      intent: context.intent,
      locale: context.locale,
      summary: context.summary,
      spec: context.spec,
      templates: context.templates,
      frames: context.frames,
      previewBase64: context.previewBase64,
      maxOps: maxOps,
    );
    final result = await api
        .aiPatch(bounded.toRequest())
        .timeout(
          deadline,
          onTimeout: () => Err<AiPatchResponse>(ApiFailure.timeout()),
        );
    return result.fold(
      ok: (response) {
        final patch = response.patch;
        if (patch.isEmpty) {
          return Err<DesignPatch>(
            ApiFailure(
              code: ApiErrorCode.aiNoProposal,
              message: 'the model returned no operations',
            ),
          );
        }
        return Ok<DesignPatch>(patch);
      },
      err: (failure) => Err<DesignPatch>(failure),
    );
  }
}
