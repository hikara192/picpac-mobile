import 'package:design_core/design_core.dart';

import 'ai_context.dart';

enum AiMode {
  remote,

  quick,
}

final class AiCapability {
  const AiCapability({
    required this.skillId,
    required this.skillVersion,
    required this.toolSchemaVersion,
    required this.model,
    required this.maxOps,
    required this.isLocal,
  });

  static const AiCapability local = AiCapability(
    skillId: DesignAdvisor.skillId,
    skillVersion: DesignAdvisor.skillVersion,
    toolSchemaVersion: DesignAdvisor.toolSchemaVersion,
    model: DesignAdvisor.model,
    maxOps: kMaxPatchOperations,
    isLocal: true,
  );

  static const AiCapability remote = AiCapability(
    skillId: 'picpac.bff.editor',
    skillVersion: '1',
    toolSchemaVersion: '1',
    model: 'bff',
    maxOps: kMaxPatchOperations,
    isLocal: false,
  );

  final String skillId;

  final String skillVersion;

  final String toolSchemaVersion;

  final String model;

  final int maxOps;

  final bool isLocal;

  AiMode get mode => isLocal ? AiMode.quick : AiMode.remote;

  Map<String, Object?> toJson() => <String, Object?>{
    'skillId': skillId,
    'skillVersion': skillVersion,
    'toolSchemaVersion': toolSchemaVersion,
    'model': model,
    'maxOps': maxOps,
    'isLocal': isLocal,
  };

  @override
  String toString() => 'AiCapability($skillId@$skillVersion, model $model)';
}

abstract interface class AiPort {
  AiCapability get capability;

  Future<Result<DesignPatch>> propose(AiContext context);
}

final class AiSuggestion {
  const AiSuggestion({
    required this.patch,
    required this.capability,
    this.warnings = const <String>[],
  });

  final DesignPatch patch;

  final AiCapability capability;

  final List<String> warnings;

  AiMode get mode => capability.mode;

  @override
  String toString() =>
      'AiSuggestion(${patch.operationCount} ops, ${mode.name})';
}
