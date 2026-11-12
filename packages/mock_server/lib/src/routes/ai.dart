import 'dart:convert';
import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../ai/agent_provider.dart';
import '../context.dart';
import '../errors.dart';
import '../mock_server.dart';

const int kAiPatchMaxBodyBytes = 4 << 20;

const String kAiNotConfigured = 'ai_not_configured';

enum AiProviderKind {
  mock,

  none,

  agent;

  static AiProviderKind current() {
    final raw = _configured.toLowerCase().trim();
    return switch (raw) {
      'none' || 'off' || 'disabled' => AiProviderKind.none,
      'agent' ||
      'opencode' ||
      'opencode-go' ||
      'pi' ||
      'pi-agent' => AiProviderKind.agent,
      _ => AiProviderKind.mock,
    };
  }

  static const String _define = String.fromEnvironment(
    'AI_PROVIDER',
    defaultValue: 'mock',
  );

  static String get _configured {
    final fromProcess = Platform.environment['AI_PROVIDER']?.trim();
    if (fromProcess != null && fromProcess.isNotEmpty) return fromProcess;
    return _define;
  }
}

void registerAiRoutes(Router router, MockServer server) {
  final kind = AiProviderKind.current();
  final advisor = const AdvisorProvider();
  final agent = kind == AiProviderKind.agent
      ? AgentProvider(config: server.agentConfig, log: server.log)
      : null;
  final provider = agent ?? advisor;

  router.post('/v1/ai/patch', (Request request) async {
    final ctx = contextOf(request);
    ctx.requireSession();
    if (kind == AiProviderKind.none) {
      throw const ApiException(
        503,
        ApiErrorCode.aiDisabled,
        'the AI contour is disabled on this server (AI_PROVIDER=none)',
      );
    }
    if (agent != null && !agent.config.isConfigured) {
      throw const ApiException(
        503,
        kAiNotConfigured,
        'AI_PROVIDER=agent is set but AGENT_BASE_URL is empty: set '
        'AGENT_BASE_URL (OpenAI-compatible base, e.g. http://127.0.0.1:8080/v1), '
        'AGENT_MODEL and AGENT_API_KEY on the BFF process',
      );
    }

    final body = await ctx.jsonBody(maxBytes: kAiPatchMaxBodyBytes);
    final parsed = decodeJson<AiPatchRequest>(body, AiPatchRequest.fromJson);
    final dto = switch (parsed) {
      Ok<AiPatchRequest>(:final value) => value,
      Err<AiPatchRequest>(:final error) => throw ApiException(
        422,
        ApiErrorCode.validationFailed,
        error.message,
        fieldErrors: const <String, String>{'body': 'invalid_ai_request'},
        extra: <String, Object?>{'requestCode': error.code},
      ),
    };

    final maxOps = dto.limits.maxOps <= 0
        ? kMaxPatchOperations
        : dto.limits.maxOps.clamp(1, kMaxPatchOperations);
    final intentHash = _hash(dto.intent);
    final result = await provider.propose(
      AiProviderRequest(
        intent: dto.intent,
        locale: dto.locale,
        summary: dto.context.summary,
        spec: dto.context.spec,
        maxOps: maxOps,
        templates: dto.context.templates,
        frameStats: dto.context.frames,
        previewBase64: dto.context.previewBase64,
      ),
    );

    final revalidated = DesignPatch.fromJson(result.patch.toJson());
    final patch = switch (revalidated) {
      Ok<DesignPatch>(:final value) => value,
      Err<DesignPatch>(:final error) => throw ApiException(
        502,
        'ai_invalid_patch',
        'the provider returned a patch that violates the protocol: '
            '${error.message}',
        extra: <String, Object?>{
          if (error is PatchRejected) 'reason': error.reason.wire,
        },
      ),
    };
    if (patch.operations.length > maxOps) {
      throw ApiException(
        502,
        'ai_invalid_patch',
        'the provider returned ${patch.operations.length} operations, the '
            'limit is $maxOps',
      );
    }

    ctx.audit(
      action: 'ai.patch',
      objectType: 'ai_request',
      objectId: _auditObjectId(patch),
      result: patch.isEmpty ? 'no_proposal' : 'success',
      details: <String, Object?>{
        'provider': result.provider,
        'ops': patch.operations.length,
        'intentHash': intentHash,
        'hasPreview': dto.context.previewBase64 != null,
        'matched': result.warnings.isEmpty,
        'revision': patch.baseRevision,
      },
    );

    if (patch.isEmpty) {
      if (agent != null) {
        throw ApiException(
          422,
          ApiErrorCode.aiNoProposal,
          'the model proposed no change for this intent',
          extra: <String, Object?>{
            'warnings': result.warnings,
            'revision': patch.baseRevision,
          },
        );
      }
      return ctx.json(_responseBody(patch, result));
    }

    return ctx.json(_responseBody(patch, result));
  });
}

Map<String, Object?> _responseBody(DesignPatch patch, AiProviderResult result) {
  final response = AiPatchResponse.of(
    patch,
    warnings: result.warnings,
  ).toJson();
  final existing = response['meta'];
  final meta = <String, Object?>{
    if (existing is Map<String, Object?>) ...existing,
    'provider': result.provider,
  };
  return <String, Object?>{...response, 'meta': meta};
}

String _auditObjectId(DesignPatch patch) =>
    'patch-${patch.baseRevision}-${patch.operations.length}';

String _hash(String value) =>
    sha256.convert(utf8.encode(value)).toString().substring(0, 12);
