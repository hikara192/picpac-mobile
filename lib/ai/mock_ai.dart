import 'package:api_contract/api_contract.dart';

import 'ai_context.dart';
import 'ai_port.dart';

final class MockAi implements AiPort {
  const MockAi();

  @override
  AiCapability get capability => AiCapability.local;

  @override
  Future<Result<DesignPatch>> propose(AiContext context) async {
    final patch = DesignAdvisor.propose(
      summary: context.summary,
      intent: context.intent,
      maxOps: context.maxOps,
      templates: <String, int>{
        for (final template in context.templates)
          template.id: template.slotCount,
      },
    );
    if (patch.isEmpty) {
      return Err<DesignPatch>(
        const ApiFailure(
          code: ApiErrorCode.aiNoProposal,
          message: 'the rules found nothing to change for this intent',
        ),
      );
    }
    return Ok<DesignPatch>(patch);
  }
}
