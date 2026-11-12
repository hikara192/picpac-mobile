import 'dart:async';
import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../security.dart';

const String kAgentSkillId = 'picpac.agent.design';

const String kAgentSkillVersion = '1.0.0';

const String kAgentToolSchemaVersion = '1';

const String kAgentProvider = 'agent';

const String kAdvisorProvider = 'advisor';

const String kWarningIntentNotRecognised = 'intent_not_recognised';

const Duration kAgentTimeout = Duration(seconds: 20);

final class AiProviderRequest {
  const AiProviderRequest({
    required this.intent,
    required this.locale,
    required this.summary,
    required this.spec,
    required this.maxOps,
    this.templates = const <AiTemplateOption>[],
    this.frameStats = const <AiFrameStats>[],
    this.previewBase64,
  });

  final String intent;

  final String locale;

  final DocumentSummary summary;

  final PrintSpec spec;

  final int maxOps;

  final List<AiTemplateOption> templates;

  final List<AiFrameStats> frameStats;

  final String? previewBase64;
}

final class AiProviderResult {
  const AiProviderResult({
    required this.provider,
    required this.patch,
    required this.meta,
    this.warnings = const <String>[],
  });

  factory AiProviderResult.fallback({
    required String reason,
    required AiProviderResult advisor,
  }) => AiProviderResult(
    provider: advisor.provider,
    patch: advisor.patch,
    meta: advisor.meta,
    warnings: <String>[reason, ...advisor.warnings],
  );

  final String provider;

  final DesignPatch patch;

  final PatchMeta meta;

  final List<String> warnings;
}

abstract interface class AiProvider {
  String get name;

  Future<AiProviderResult> propose(AiProviderRequest request);
}

final class AdvisorProvider implements AiProvider {
  const AdvisorProvider();

  @override
  String get name => kAdvisorProvider;

  @override
  Future<AiProviderResult> propose(AiProviderRequest request) async {
    final patch = DesignAdvisor.propose(
      summary: request.summary,
      intent: request.intent,
      maxOps: request.maxOps,
      templates: _offeredTemplates(request),
    );
    return AiProviderResult(
      provider: name,
      patch: patch,
      meta: patch.meta,
      warnings: patch.isEmpty
          ? const <String>[kWarningIntentNotRecognised]
          : const <String>[],
    );
  }
}

Map<String, int> _offeredTemplates(AiProviderRequest request) {
  final offered = <String, int>{
    for (final template in request.templates) template.id: template.slotCount,
  };
  for (final spread in request.summary.spreads) {
    offered.putIfAbsent(spread.templateId, () => spread.slotCount);
  }
  return offered;
}

final class AgentConfig {
  const AgentConfig({
    required this.baseUrl,
    this.apiKey = '',
    this.model = '',
    this.timeout = kAgentTimeout,
    this.maxAttempts = 2,
  });

  factory AgentConfig.fromEnv() => AgentConfig(
    baseUrl: MockEnv.agentBaseUrl ?? '',
    apiKey: MockEnv.agentApiKey ?? '',
    model: MockEnv.agentModel ?? '',
  );

  final String baseUrl;

  final String apiKey;

  final String model;

  final Duration timeout;

  final int maxAttempts;

  bool get isConfigured => baseUrl.trim().isNotEmpty;

  Uri get chatCompletionsUri => Uri.parse(
    '${baseUrl.trim().replaceAll(RegExp(r'/+$'), '')}/chat/completions',
  );
}

final class AgentProvider implements AiProvider {
  AgentProvider({
    required this.config,
    this.client,
    this.log,
    this.fallback = const AdvisorProvider(),
  });

  final AgentConfig config;

  final http.Client? client;

  final void Function(String line)? log;

  final AiProvider fallback;

  @override
  String get name => kAgentProvider;

  @override
  Future<AiProviderResult> propose(AiProviderRequest request) async {
    if (!config.isConfigured) {
      return _fallback(request, 'ai_not_configured');
    }

    final promptHash = sha256
        .convert(utf8.encode(kAgentSystemPrompt))
        .toString();
    final body = _requestBody(request);
    final _Attempt attempt;
    try {
      attempt = await _post(body);
    } on TimeoutException {
      return _fallback(request, 'agent_timeout');
    } on http.ClientException {
      return _fallback(request, 'agent_unavailable');
    } on Exception {
      return _fallback(request, 'agent_unavailable');
    }

    if (attempt.content == null) {
      return _fallback(request, attempt.reason ?? 'agent_unavailable');
    }

    final json = _extractJsonObject(attempt.content!);
    if (json == null) return _fallback(request, 'agent_invalid_json');
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return _fallback(request, 'agent_invalid_json');
    }
    final DesignPatch patch;
    try {
      patch = DesignPatch.fromJsonOrThrow(decoded);
    } on PatchRejected catch (error) {
      return _fallback(request, error.reason.wire);
    } on DesignFormatException {
      return _fallback(request, 'agent_invalid_patch');
    }

    final violation = _summaryViolation(patch, request);
    if (violation != null) return _fallback(request, violation);

    final meta = PatchMeta(
      skillId: kAgentSkillId,
      skillVersion: kAgentSkillVersion,
      toolSchemaVersion: kAgentToolSchemaVersion,
      model: _modelOf(attempt),
      promptHash: promptHash,
    );
    final proposal = DesignPatch(
      schema: patch.schema,
      baseRevision: patch.baseRevision,
      operations: patch.operations,
      meta: meta,
    );
    log?.call(
      'ai.agent response model=${_redact(meta.model)} '
      'promptHash=${promptHash.substring(0, 12)} ops=${proposal.operationCount}',
    );
    return AiProviderResult(
      provider: name,
      patch: proposal,
      meta: meta,
      warnings: proposal.isEmpty
          ? const <String>[kWarningIntentNotRecognised]
          : const <String>[],
    );
  }

  Future<AiProviderResult> _fallback(
    AiProviderRequest request,
    String reason,
  ) async {
    log?.call('ai.agent fallback reason=$reason');
    final advisor = await fallback.propose(request);
    return AiProviderResult.fallback(reason: reason, advisor: advisor);
  }

  Future<_Attempt> _post(Map<String, Object?> body) async {
    final payload = jsonEncode(body);
    final headers = <String, String>{
      'content-type': 'application/json',
      if (config.apiKey.isNotEmpty) 'authorization': 'Bearer ${config.apiKey}',
    };
    log?.call(
      'ai.agent request model=${_redact(config.model)} bytes=${payload.length}',
    );

    final owns = client == null;
    final transport = client ?? http.Client();
    try {
      for (var attempt = 1; attempt <= config.maxAttempts; attempt++) {
        final response = await transport
            .post(config.chatCompletionsUri, headers: headers, body: payload)
            .timeout(config.timeout);
        final retryable =
            response.statusCode == 429 || response.statusCode >= 500;
        if (response.statusCode == 200) {
          return _readReply(response.body, response.statusCode);
        }
        if (!retryable || attempt >= config.maxAttempts) {
          log?.call('ai.agent request failed status=${response.statusCode}');
          return _Attempt(
            status: response.statusCode,
            reason: response.statusCode == 429
                ? 'agent_rate_limited'
                : 'agent_error',
          );
        }
        log?.call('ai.agent retry status=${response.statusCode}');
      }
    } finally {
      if (owns) transport.close();
    }
    return const _Attempt(status: 0, reason: 'agent_unavailable');
  }

  _Attempt _readReply(String body, int status) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return _Attempt(status: status, reason: 'agent_invalid_json');
    }
    if (decoded is! Map<String, Object?>) {
      return _Attempt(status: status, reason: 'agent_invalid_json');
    }
    final model = decoded['model'];
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      return _Attempt(
        status: status,
        model: model is String ? model : null,
        reason: 'agent_invalid_response',
      );
    }
    final first = choices.first;
    if (first is! Map) {
      return _Attempt(status: status, reason: 'agent_invalid_response');
    }
    final message = first['message'];
    if (message is! Map) {
      return _Attempt(status: status, reason: 'agent_invalid_response');
    }
    final content = message['content'];
    final String? text;
    if (content is String) {
      text = content;
    } else if (content is List) {
      text = content
          .whereType<Map>()
          .where((part) => part['text'] is String)
          .map((part) => part['text'] as String)
          .join();
    } else {
      text = null;
    }
    return _Attempt(
      status: status,
      content: text == null || text.trim().isEmpty ? null : text,
      model: model is String ? model : null,
      reason: text == null || text.trim().isEmpty
          ? 'agent_empty_response'
          : null,
    );
  }

  String _modelOf(_Attempt attempt) {
    final reported = attempt.model?.trim();
    if (reported != null && reported.isNotEmpty) return reported;
    final configured = config.model.trim();
    return configured.isEmpty ? kAgentProvider : configured;
  }

  Map<String, Object?> _requestBody(AiProviderRequest request) {
    final preview = request.previewBase64;
    final context = <String, Object?>{
      'intent': request.intent,
      'locale': request.locale,
      'maxOps': request.maxOps,
      'summary': request.summary.toJson(),
      'spec': request.spec.toJson(),
      if (request.templates.isNotEmpty)
        'templates': <Object?>[
          for (final template in request.templates) template.toJson(),
        ],
      if (request.frameStats.isNotEmpty)
        'frames': <Object?>[
          for (final frame in request.frameStats) frame.toJson(),
        ],
    };
    final userParts = <Map<String, Object?>>[
      <String, Object?>{'type': 'text', 'text': jsonEncode(context)},
      if (preview != null && preview.isNotEmpty)
        <String, Object?>{
          'type': 'image_url',
          'image_url': <String, Object?>{
            'url': 'data:image/png;base64,$preview',
          },
        },
    ];
    log?.call(
      'ai.agent multimodal previewChars=${preview?.length ?? 0} '
      'frames=${request.frameStats.length}',
    );
    return <String, Object?>{
      'model': config.model,
      'temperature': 0,
      'messages': <Object?>[
        <String, Object?>{'role': 'system', 'content': kAgentSystemPrompt},
        <String, Object?>{'role': 'user', 'content': userParts},
      ],
    };
  }

  String? _summaryViolation(DesignPatch patch, AiProviderRequest request) {
    if (patch.baseRevision != request.summary.revision) {
      return PatchErrorCode.revisionMismatch.wire;
    }
    if (patch.operationCount > request.maxOps) {
      return PatchErrorCode.tooManyOperations.wire;
    }
    final slots = <String, Set<String>>{
      for (final spread in request.summary.spreads)
        spread.id: <String>{for (final slot in spread.slots) slot.id},
    };
    final photos = <String>{
      for (final spread in request.summary.spreads)
        for (final slot in spread.slots)
          if (slot.photoId != null) slot.photoId!,
      ...request.summary.unassignedPhotoIds,
    };
    final templates = <String>{
      for (final spread in request.summary.spreads) spread.templateId,
      for (final template in request.templates) template.id,
      ...BuiltInTemplates.byId.keys,
    };

    String? requireSlot(String spreadId, String slotId) {
      final spread = slots[spreadId];
      if (spread == null) return PatchErrorCode.spreadNotFound.wire;
      if (!spread.contains(slotId)) return PatchErrorCode.slotNotFound.wire;
      return null;
    }

    for (final operation in patch.operations) {
      if (operation is AssignPhotoOperation && operation.photoId == null) {
        return PatchErrorCode.invalidOperation.wire;
      }
      final violation = switch (operation) {
        SetCropOperation(:final spreadId, :final slotId) => requireSlot(
          spreadId,
          slotId,
        ),
        AssignPhotoOperation(:final spreadId, :final slotId) => requireSlot(
          spreadId,
          slotId,
        ),
        ReplacePhotoOperation(:final spreadId, :final slotId) => requireSlot(
          spreadId,
          slotId,
        ),
        SwapSlotsOperation(
          :final spreadA,
          :final slotA,
          :final spreadB,
          :final slotB,
        ) =>
          requireSlot(spreadA, slotA) ?? requireSlot(spreadB, slotB),
        SetLayoutOperation(:final templateId) =>
          templates.contains(templateId)
              ? null
              : PatchErrorCode.unknownTemplate.wire,
        _ => null,
      };
      if (violation != null) return violation;

      final spreadIds = switch (operation) {
        SetBackgroundOperation(:final spreadIds) => spreadIds,
        SetLayoutOperation(:final spreadIds) => spreadIds,
        _ => null,
      };
      for (final spreadId in spreadIds ?? const <String>[]) {
        if (!slots.containsKey(spreadId)) {
          return PatchErrorCode.spreadNotFound.wire;
        }
      }

      final photoIds = switch (operation) {
        AssignPhotoOperation(:final photoId) => <String>[?photoId],
        ReplacePhotoOperation(:final photoId) => <String>[photoId],
        SetAdjustmentOperation(:final photoIds) => photoIds ?? const <String>[],
        ApplyLookOperation(:final photoIds) => photoIds ?? const <String>[],
        _ => const <String>[],
      };
      for (final photoId in photoIds) {
        if (!photos.contains(photoId)) return PatchErrorCode.photoNotFound.wire;
      }
    }
    return null;
  }
}

final class _Attempt {
  const _Attempt({required this.status, this.content, this.model, this.reason});

  final int status;

  final String? content;

  final String? model;

  final String? reason;
}

String? _extractJsonObject(String raw) {
  final fenced = RegExp(
    r'```(?:json)?\s*([\s\S]*?)```',
    caseSensitive: false,
  ).firstMatch(raw);
  final candidate = fenced?.group(1) ?? raw;
  final start = candidate.indexOf('{');
  final end = candidate.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  return candidate.substring(start, end + 1);
}

String _redact(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'none';
  return trimmed.length <= 48 ? trimmed : '${trimmed.substring(0, 48)}…';
}

const String kAgentSystemPrompt = '''
You are the design assistant of PicPac, a photo-print app. You never see original
photos: you get a JSON description of the project, statistics of up to four
frames and one rendered preview of the current sheet.

TASK
Turn the user's intent into a minimal set of typed operations that change the
current sheet(s). Prefer one operation that covers many photos over one per photo.

OUTPUT
Return ONLY a JSON object, no prose, no markdown, no comments:
{"schema":1,"baseRevision":<revision from the context>,"ops":[...]}

RULES
- baseRevision MUST equal context.summary.revision.
- Use at most context.maxOps operations.
- Never invent ids: every spreadId, slotId, photoId, templateId and lookId MUST
  appear in the context (lookId must be one of the looks listed below).
- Never delete a photo: do not send "assignPhoto" with photoId null or absent.
  A slot that holds a photo must keep one.
- Coordinates are normalized: crop {x,y,w,h} within 0..1, zoom 1..8, anchor
  {x,y} within 0..1.
- Do not change the number of sheets: "setLayout" only reshapes existing sheets.
- If nothing should change, return {"schema":1,"baseRevision":<rev>,"ops":[]}.

OPERATIONS (the only allowed values of "op")
1. setCrop {"op":"setCrop","spreadId","slotId","crop":{"x","y","w","h"},"zoom"?,"anchor"?}
   Reframes one filled slot. Keep w/h when re-centring.
2. setAdjustment {"op":"setAdjustment","field","value","photoIds"?}
   field: exposure (-2..2 EV, step 0.05), contrast (-100..100), temperature
   (-100..100, positive is warmer), tint (-100..100), saturation (-100..100),
   vibrance (-100..100). Omit "photoIds" to target every photo of the document.
   Prefer the gentle end of the range: temperature within +/-20, contrast within
   +/-40, saturation within +/-12, exposure within +/-0.3.
3. applyLook {"op":"applyLook","lookId","strength"?,"photoIds"?}
   lookId: as_is, warm, film, bright, soft, mono (strength 0..1, default 1).
4. assignPhoto {"op":"assignPhoto","spreadId","slotId","photoId"}
   Fills an empty slot. "photoId" is required.
5. replacePhoto {"op":"replacePhoto","spreadId","slotId","photoId"}
   Swaps the photo of a filled slot; "photoId" is required.
6. setBackground {"op":"setBackground","type","value","spreadIds"?}
   type: "color" with value "#RRGGBB", or "gradient" with a descriptor string.
7. setLayout {"op":"setLayout","templateId","spreadIds"?}
   templateId: a template id from the context. Never changes the sheet count.
8. swapSlots {"op":"swapSlots","spreadA","slotA","spreadB","slotB"}
   Exchanges the content of two slots, framing included.

If the intent is already satisfied, or you cannot express it with these
operations, return an empty "ops" array. An invalid answer is discarded whole.''';
