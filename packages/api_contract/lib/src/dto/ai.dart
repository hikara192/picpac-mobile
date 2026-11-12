import 'package:design_core/design_core.dart';

import '../failure.dart';
import '../json.dart';

final class AiLimits with ValueJson {
  const AiLimits({this.maxOps = kMaxPatchOperations});

  final int maxOps;

  @override
  Map<String, Object?> toJson() => <String, Object?>{'maxOps': maxOps};

  factory AiLimits.fromJson(JsonMap json, [String path = r'$']) => AiLimits(
    maxOps:
        J.readIntOrNull(json['maxOps'], '$path.maxOps') ?? kMaxPatchOperations,
  );
}

final class AiTemplateOption with ValueJson {
  const AiTemplateOption({required this.id, required this.slotCount});

  final String id;

  final int slotCount;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'slotCount': slotCount,
  };

  factory AiTemplateOption.fromJson(JsonMap json, [String path = r'$']) =>
      AiTemplateOption(
        id: J.readId(json['id'], '$path.id'),
        slotCount: J.readInt(json['slotCount'], '$path.slotCount'),
      );
}

final class AiFrameStats with ValueJson {
  const AiFrameStats({
    required this.photoId,
    required this.lumaMean,
    required this.lumaP1,
    required this.lumaP99,
    required this.meanR,
    required this.meanG,
    required this.meanB,
    required this.chromaMean,
    required this.highlightFraction,
  });

  final String photoId;

  final double lumaMean;

  final double lumaP1;

  final double lumaP99;

  final double meanR;

  final double meanG;

  final double meanB;

  final double chromaMean;

  final double highlightFraction;

  factory AiFrameStats.of(PhotoAnalysis analysis, {required String photoId}) =>
      AiFrameStats(
        photoId: photoId,
        lumaMean: analysis.lumaMean,
        lumaP1: analysis.lumaP1,
        lumaP99: analysis.lumaP99,
        meanR: analysis.meanR,
        meanG: analysis.meanG,
        meanB: analysis.meanB,
        chromaMean: analysis.chromaMean,
        highlightFraction: analysis.highlightFraction,
      );

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'photoId': photoId,
    'lumaMean': lumaMean,
    'lumaP1': lumaP1,
    'lumaP99': lumaP99,
    'meanR': meanR,
    'meanG': meanG,
    'meanB': meanB,
    'chromaMean': chromaMean,
    'highlightFraction': highlightFraction,
  };

  factory AiFrameStats.fromJson(JsonMap json, [String path = r'$']) =>
      AiFrameStats(
        photoId: J.readId(json['photoId'], '$path.photoId'),
        lumaMean: J.readDouble(json['lumaMean'], '$path.lumaMean'),
        lumaP1: J.readDouble(json['lumaP1'], '$path.lumaP1'),
        lumaP99: J.readDouble(json['lumaP99'], '$path.lumaP99'),
        meanR: J.readDouble(json['meanR'], '$path.meanR'),
        meanG: J.readDouble(json['meanG'], '$path.meanG'),
        meanB: J.readDouble(json['meanB'], '$path.meanB'),
        chromaMean: J.readDouble(json['chromaMean'], '$path.chromaMean'),
        highlightFraction: J.readDouble(
          json['highlightFraction'],
          '$path.highlightFraction',
        ),
      );
}

final class AiRequestContext with ValueJson {
  const AiRequestContext({
    required this.summary,
    required this.spec,
    this.templates = const <AiTemplateOption>[],
    this.frames = const <AiFrameStats>[],
    this.previewBase64,
  });

  final DocumentSummary summary;

  final PrintSpec spec;

  final List<AiTemplateOption> templates;

  final List<AiFrameStats> frames;

  final String? previewBase64;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'summary': summary.toJson(),
    'spec': spec.toJson(),
    if (templates.isNotEmpty)
      'templates': <Object?>[
        for (final template in templates) template.toJson(),
      ],
    if (frames.isNotEmpty)
      'frames': <Object?>[for (final frame in frames) frame.toJson()],
    if (previewBase64 != null) 'previewBase64': previewBase64,
  };

  factory AiRequestContext.fromJson(JsonMap json, [String path = r'$']) {
    final parsed = DocumentSummary.fromJson(json['summary']);
    final summary = switch (parsed) {
      Ok<DocumentSummary>(:final value) => value,
      Err<DocumentSummary>(:final error) => throw ApiFailure(
        code: ApiErrorCode.invalidResponse,
        message: 'invalid AI summary: ${error.message}',
        args: <String, Object?>{'path': '$path.summary', 'code': error.code},
      ),
    };
    final templatesJson = json['templates'] == null
        ? const <Object?>[]
        : J.readList(json['templates'], '$path.templates');
    final framesJson = json['frames'] == null
        ? const <Object?>[]
        : J.readList(json['frames'], '$path.frames');
    return AiRequestContext(
      summary: summary,
      spec: PrintSpec.fromJson(json['spec'], '$path.spec'),
      templates: <AiTemplateOption>[
        for (var i = 0; i < templatesJson.length; i++)
          AiTemplateOption.fromJson(
            J.readObject(templatesJson[i], '$path.templates[$i]'),
            '$path.templates[$i]',
          ),
      ],
      frames: <AiFrameStats>[
        for (var i = 0; i < framesJson.length; i++)
          AiFrameStats.fromJson(
            J.readObject(framesJson[i], '$path.frames[$i]'),
            '$path.frames[$i]',
          ),
      ],
      previewBase64: J.readStringOrNull(
        json['previewBase64'],
        '$path.previewBase64',
      ),
    );
  }
}

final class AiPatchRequest with ValueJson {
  const AiPatchRequest({
    required this.intent,
    required this.locale,
    required this.context,
    this.limits = const AiLimits(),
  });

  final String intent;

  final String locale;

  final AiRequestContext context;

  final AiLimits limits;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'intent': intent,
    'locale': locale,
    'context': context.toJson(),
    'limits': limits.toJson(),
  };

  factory AiPatchRequest.fromJson(JsonMap json, [String path = r'$']) {
    final limitsJson = json['limits'];
    return AiPatchRequest(
      intent: J.readId(json['intent'], '$path.intent'),
      locale: J.readStringOrNull(json['locale'], '$path.locale') ?? 'ru',
      context: AiRequestContext.fromJson(
        J.readObject(json['context'], '$path.context'),
        '$path.context',
      ),
      limits: limitsJson == null
          ? const AiLimits()
          : AiLimits.fromJson(
              J.readObject(limitsJson, '$path.limits'),
              '$path.limits',
            ),
    );
  }
}

final class AiPatchResponse with ValueJson {
  const AiPatchResponse({
    required this.patch,
    this.meta = const PatchMeta(),
    this.warnings = const <String>[],
  });

  final DesignPatch patch;

  final PatchMeta meta;

  final List<String> warnings;

  factory AiPatchResponse.of(
    DesignPatch patch, {
    List<String> warnings = const <String>[],
  }) => AiPatchResponse(patch: patch, meta: patch.meta, warnings: warnings);

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'patch': patch.toJson(),
    if (!meta.isEmpty) 'meta': meta.toJson(),
    'warnings': warnings,
  };

  factory AiPatchResponse.fromJson(JsonMap json, [String path = r'$']) {
    final parsed = DesignPatch.fromJson(json['patch']);
    final patch = switch (parsed) {
      Ok<DesignPatch>(:final value) => value,
      Err<DesignPatch>(:final error) => throw ApiFailure(
        code: ApiErrorCode.invalidResponse,
        message: 'invalid AI patch: ${error.message}',
        args: <String, Object?>{
          'path': '$path.patch',
          if (error is PatchRejected) 'reason': error.reason.wire,
          if (error is PatchRejected && error.opIndex != null)
            'opIndex': error.opIndex,
        },
      ),
    };
    final warningsJson = json['warnings'] == null
        ? const <Object?>[]
        : J.readList(json['warnings'], '$path.warnings');
    return AiPatchResponse(
      patch: patch,
      meta: json['meta'] == null
          ? patch.meta
          : PatchMeta.fromJson(J.readObject(json['meta'], '$path.meta')),
      warnings: <String>[
        for (var i = 0; i < warningsJson.length; i++)
          J.readString(warningsJson[i], '$path.warnings[$i]'),
      ],
    );
  }
}
