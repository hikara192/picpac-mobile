import 'package:api_contract/api_contract.dart';

final class AiContext {
  const AiContext({
    required this.intent,
    required this.locale,
    required this.summary,
    required this.spec,
    this.templates = const <AiTemplateOption>[],
    this.frames = const <AiFrameStats>[],
    this.previewBase64,
    this.maxOps = kMaxPatchOperations,
  });

  final String intent;

  final String locale;

  final DocumentSummary summary;

  final PrintSpec spec;

  final List<AiTemplateOption> templates;

  final List<AiFrameStats> frames;

  final String? previewBase64;

  final int maxOps;

  int get revision => summary.revision;

  int get previewBytes => previewBase64?.length ?? 0;

  AiPatchRequest toRequest() => AiPatchRequest(
    intent: intent,
    locale: locale,
    context: AiRequestContext(
      summary: summary,
      spec: spec,
      templates: templates,
      frames: frames,
      previewBase64: previewBase64,
    ),
    limits: AiLimits(maxOps: maxOps),
  );

  Map<String, Object?> describe() => <String, Object?>{
    'revision': revision,
    'photos': summary.photoStats.photoCount,
    'spreads': summary.materialisedSpreads,
    'emptySlots': summary.emptySlotCount,
    'freePhotos': summary.unassignedPhotoIds.length,
    'frames': frames.length,
    'hasPreview': previewBase64 != null,
    'maxOps': maxOps,
  };

  @override
  String toString() =>
      'AiContext(r$revision, ${summary.photoStats.photoCount} photos, '
      '${previewBase64 == null ? 'no preview' : '$previewBytes B preview'})';
}
