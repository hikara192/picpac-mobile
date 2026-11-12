import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai/ai_context.dart';
import '../../../ai/ai_port.dart';
import '../../../ai/ai_preview.dart';
import '../../../ai/ai_providers.dart';
import '../../../ai/ai_router.dart';
import '../../../core/media/asset_cache.dart';
import '../../_shared/application/design_session.dart';
import '../../_shared/application/frame_analyzer.dart';
import '../../../render/asset_image_store.dart';

final class AssistantRequest {
  const AssistantRequest({
    required this.designId,
    required this.intent,
    required this.localeName,
    required this.state,
    required this.spread,
    required this.images,
    required this.cache,
    required this.analyzer,
    this.localOnly = false,
  });

  final String designId;

  final String intent;

  final String localeName;

  final DesignSessionState state;

  final Spread spread;

  final AssetImageStore images;

  final DesignAssetCache cache;

  final FrameAnalyzer analyzer;

  final bool localOnly;
}

final class AssistantProposal {
  const AssistantProposal({required this.suggestion, required this.resolution});

  final AiSuggestion suggestion;

  final PatchResolution resolution;

  AiMode get mode => suggestion.mode;

  EditPlan get plan => resolution.plan;

  List<PreflightIssue> get warnings => resolution.warnings;

  bool get removesPhoto => plan.removesPhotos;

  DesignDocument previewOf(DesignDocument document) =>
      resolution.previewOf(document);
}

final class AssistantService {
  const AssistantService({required this.router});

  final AiRouter router;

  static const int maxFrames = 4;

  Future<Result<AssistantProposal>> ask(AssistantRequest request) async {
    final context = await buildContext(request);
    final suggestion = await router.suggest(
      AiRequest(context: context, localOnly: request.localOnly),
    );
    return suggestion.fold(
      ok: (value) {
        final resolved = PatchApplier.resolve(
          request.state.document,
          value.patch,
          templates: request.state.templates,
          spec: request.state.spec,
        );
        return resolved.map(
          (resolution) =>
              AssistantProposal(suggestion: value, resolution: resolution),
        );
      },
      err: (failure) => Err<AssistantProposal>(failure),
    );
  }

  Future<AiContext> buildContext(AssistantRequest request) async {
    final state = request.state;
    final template = state.templateOf(request.spread);
    final preview = await renderPreviewBase64(
      document: state.document,
      spread: request.spread,
      template: template,
      spec: state.spec,
      images: request.images,
    );
    return AiContext(
      intent: request.intent,
      locale: request.localeName,
      summary: DocumentSummary.from(state.document),
      spec: state.spec,
      templates: <AiTemplateOption>[
        for (final entry in state.templates.entries)
          AiTemplateOption(id: entry.key, slotCount: entry.value.slotCount),
      ],
      frames: await _frames(request),
      previewBase64: preview,
    );
  }

  Future<List<AiFrameStats>> _frames(AssistantRequest request) async {
    final frames = <AiFrameStats>[];
    final document = request.state.document;
    for (final slot in request.spread.slots) {
      if (frames.length >= maxFrames) break;
      final photoId = slot.photoId;
      if (photoId == null) continue;
      final asset = document.assetById(photoId);
      if (asset == null) continue;
      try {
        final file = await request.cache.fileFor(
          request.designId,
          asset.sha256,
        );
        if (file == null) continue;
        final stats = await request.analyzer.analyze(file.path);
        if (stats == null) continue;
        final analysis = PhotoAnalysis.tryOf(stats);
        if (analysis == null || analysis.pixelCount == 0) continue;
        frames.add(AiFrameStats.of(analysis, photoId: photoId));
      } on Object {
      }
    }
    return frames;
  }
}

final assistantServiceProvider = Provider<AssistantService>(
  (ref) => AssistantService(router: ref.watch(aiRouterProvider)),
);
