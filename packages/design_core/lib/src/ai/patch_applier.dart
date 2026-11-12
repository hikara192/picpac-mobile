import 'package:meta/meta.dart';

import '../commands/adjustment_commands.dart';
import '../commands/command_result.dart';
import '../commands/design_command.dart';
import '../commands/placement_commands.dart';
import '../commands/slot_commands.dart';
import '../core/result.dart';
import '../document/design_document.dart';
import '../document/print_spec.dart';
import '../document/spread.dart';
import '../preflight/preflight_model.dart';
import '../preflight/preflight_projection.dart';
import '../templates/built_in_templates.dart';
import '../templates/print_template.dart';
import 'design_patch.dart';
import 'edit_plan.dart';

@immutable
final class PatchResolution {
  const PatchResolution({
    required this.patch,
    required this.command,
    required this.plan,
    this.warnings = const <PreflightIssue>[],
  });

  final DesignPatch patch;

  final CompositeCommand command;

  final EditPlan plan;

  final List<PreflightIssue> warnings;

  bool get hasWarnings => warnings.isNotEmpty;

  DesignDocument previewOf(DesignDocument document) =>
      command.applyCore(document);

  @override
  String toString() =>
      'PatchResolution(${command.commands.length} commands, '
      '${plan.length} changes, ${warnings.length} warnings)';
}

abstract final class PatchApplier {
  static const int defaultMaxOperations = kMaxPatchOperations;

  static Result<PatchResolution> resolve(
    DesignDocument document,
    DesignPatch patch, {
    Map<String, PrintTemplate> templates = const <String, PrintTemplate>{},
    PrintSpec? spec,
    int maxOperations = defaultMaxOperations,
    PreflightConfig config = const PreflightConfig(),
  }) {
    try {
      return Ok<PatchResolution>(
        _resolve(document, patch, templates, spec, maxOperations, config),
      );
    } on PatchRejected catch (error) {
      return Err<PatchResolution>(error);
    }
  }

  static Result<CompositeCommand> apply(
    DesignDocument document,
    DesignPatch patch, {
    Map<String, PrintTemplate> templates = const <String, PrintTemplate>{},
    PrintSpec? spec,
    int maxOperations = defaultMaxOperations,
    PreflightConfig config = const PreflightConfig(),
  }) => resolve(
    document,
    patch,
    templates: templates,
    spec: spec,
    maxOperations: maxOperations,
    config: config,
  ).map((resolution) => resolution.command);

  static PatchResolution _resolve(
    DesignDocument document,
    DesignPatch patch,
    Map<String, PrintTemplate> templates,
    PrintSpec? spec,
    int maxOperations,
    PreflightConfig config,
  ) {
    if (patch.schema != DesignPatch.currentSchema) {
      throw PatchRejected(
        reason: PatchErrorCode.unsupportedSchema,
        message: 'patch schema ${patch.schema} is not supported',
        details: <String, Object?>{
          'schema': patch.schema,
          'supported': DesignPatch.currentSchema,
        },
      );
    }
    if (patch.operations.isEmpty) {
      throw const PatchRejected(
        reason: PatchErrorCode.emptyPatch,
        message: 'the patch proposes no operations',
      );
    }
    if (patch.operations.length > maxOperations) {
      throw PatchRejected(
        reason: PatchErrorCode.tooManyOperations,
        message:
            'the patch has ${patch.operations.length} operations, the limit is '
            '$maxOperations',
        details: <String, Object?>{
          'count': patch.operations.length,
          'limit': maxOperations,
        },
      );
    }
    if (patch.baseRevision != document.revision) {
      throw PatchRejected(
        reason: PatchErrorCode.revisionMismatch,
        message:
            'the patch was built for revision ${patch.baseRevision}, the '
            'document is at ${document.revision}',
        details: <String, Object?>{
          'expected': patch.baseRevision,
          'actual': document.revision,
        },
      );
    }

    final catalog = BuiltInTemplates.mergedWith(templates);
    final commands = <DesignCommand>[];
    var current = document;

    for (var index = 0; index < patch.operations.length; index++) {
      final operation = patch.operations[index];
      final expanded = _expand(operation, current, index, catalog, templates);
      if (expanded.isEmpty) {
        throw PatchRejected(
          reason: PatchErrorCode.noEffect,
          message: 'operation ${operation.op} expands to no command',
          opIndex: index,
          operation: operation.op,
          details: <String, Object?>{
            'photos': current.assets.length,
            'spreads': current.spreads.length,
          },
        );
      }
      for (final command in expanded) {
        final validation = command.validate(current);
        if (validation case CommandFailed(:final error)) {
          throw PatchRejected(
            reason: PatchErrorCode.commandRejected,
            message: error.message,
            opIndex: index,
            operation: operation.op,
            details: <String, Object?>{
              'command': command.kind,
              'commandCode': error.code.wire,
              if (error.targetId != null) 'targetId': error.targetId,
            },
          );
        }
        current = command.applyCore(current);
        commands.add(command);
      }
    }

    if (commands.isEmpty) {
      throw const PatchRejected(
        reason: PatchErrorCode.noEffect,
        message: 'the patch expands to no command',
      );
    }

    final command = CompositeCommand(commands, label: 'aiPatch');
    final validation = command.validate(document);
    if (validation case CommandFailed(:final error)) {
      throw PatchRejected(
        reason: PatchErrorCode.commandRejected,
        message: error.message,
        details: <String, Object?>{'commandCode': error.code.wire},
      );
    }

    return PatchResolution(
      patch: patch,
      command: command,
      plan: EditPlan.of(patch, document),
      warnings: spec == null
          ? const <PreflightIssue>[]
          : _newIssues(
              before: PreflightProjection.run(
                document: document,
                spec: spec,
                templates: templates,
                config: config,
              ),
              after: PreflightProjection.run(
                document: current,
                spec: spec,
                templates: templates,
                config: config,
              ),
            ),
    );
  }

  static List<DesignCommand> _expand(
    PatchOperation operation,
    DesignDocument document,
    int index,
    Map<String, PrintTemplate> catalog,
    Map<String, PrintTemplate> templates,
  ) {
    switch (operation) {
      case SetCropOperation(
        :final spreadId,
        :final slotId,
        :final crop,
        :final zoom,
        :final anchor,
      ):
        _requireSlot(document, spreadId, slotId, operation, index);
        return <DesignCommand>[
          SetCrop(
            spreadId: spreadId,
            slotId: slotId,
            crop: crop,
            zoom: zoom,
            anchor: anchor,
          ),
        ];

      case SetAdjustmentOperation(:final field, :final value, :final photoIds):
        final targets = _photoTargets(document, photoIds, operation, index);
        return <DesignCommand>[
          for (final photoId in targets)
            SetPhotoAdjustment(photoId: photoId, field: field, value: value),
        ];

      case ApplyLookOperation(:final lookId, :final strength, :final photoIds):
        final targets = _photoTargets(document, photoIds, operation, index);
        return <DesignCommand>[
          ApplyLook(photoIds: targets, lookId: lookId, strength: strength),
        ];

      case AssignPhotoOperation(:final spreadId, :final slotId, :final photoId):
        _requireSlot(document, spreadId, slotId, operation, index);
        _requirePhoto(document, photoId, operation, index);
        return <DesignCommand>[
          AssignPhoto(spreadId: spreadId, slotId: slotId, photoId: photoId),
        ];

      case ReplacePhotoOperation(
        :final spreadId,
        :final slotId,
        :final photoId,
      ):
        _requireSlot(document, spreadId, slotId, operation, index);
        _requirePhoto(document, photoId, operation, index);
        return <DesignCommand>[
          AssignPhoto(spreadId: spreadId, slotId: slotId, photoId: photoId),
        ];

      case SetBackgroundOperation(:final type, :final value, :final spreadIds):
        final spreads = _spreadTargets(document, spreadIds, operation, index);
        final background = type == BackgroundType.gradient
            ? SpreadBackground(type: BackgroundType.gradient, value: value)
            : SpreadBackground.color(value);
        return <DesignCommand>[
          for (final spreadId in spreads)
            SetBackground(spreadId: spreadId, background: background),
        ];

      case SetLayoutOperation(:final templateId, :final spreadIds):
        final template = catalog[templateId];
        if (template == null) {
          throw PatchRejected(
            reason: PatchErrorCode.unknownTemplate,
            message: 'template "$templateId" is not offered by the format',
            opIndex: index,
            operation: operation.op,
            details: <String, Object?>{
              'templateId': templateId,
              'known': <String>[
                ...templates.keys,
                ...BuiltInTemplates.byId.keys,
              ],
            },
          );
        }
        final spreads = _spreadTargets(document, spreadIds, operation, index);
        return <DesignCommand>[
          for (final spreadId in spreads)
            SetLayout(spreadId: spreadId, template: template),
        ];

      case SwapSlotsOperation(
        :final spreadA,
        :final slotA,
        :final spreadB,
        :final slotB,
      ):
        _requireSlot(document, spreadA, slotA, operation, index);
        _requireSlot(document, spreadB, slotB, operation, index);
        return <DesignCommand>[
          SwapSlots(
            spreadA: spreadA,
            slotA: slotA,
            spreadB: spreadB,
            slotB: slotB,
          ),
        ];
    }
  }

  static List<String> _photoTargets(
    DesignDocument document,
    List<String>? photoIds,
    PatchOperation operation,
    int index,
  ) {
    if (photoIds == null) {
      return <String>[for (final asset in document.assets) asset.id];
    }
    for (final photoId in photoIds) {
      _requirePhoto(document, photoId, operation, index);
    }
    return photoIds;
  }

  static void _requirePhoto(
    DesignDocument document,
    String? photoId,
    PatchOperation operation,
    int index,
  ) {
    if (photoId == null) return;
    if (document.assetById(photoId) != null) return;
    throw PatchRejected(
      reason: PatchErrorCode.photoNotFound,
      message: 'photo "$photoId" is not in the document',
      opIndex: index,
      operation: operation.op,
      details: <String, Object?>{'photoId': photoId},
    );
  }

  static void _requireSlot(
    DesignDocument document,
    String spreadId,
    String slotId,
    PatchOperation operation,
    int index,
  ) {
    if (document.spreadById(spreadId) == null) {
      throw PatchRejected(
        reason: PatchErrorCode.spreadNotFound,
        message: 'spread "$spreadId" not found',
        opIndex: index,
        operation: operation.op,
        details: <String, Object?>{'spreadId': spreadId},
      );
    }
    if (document.slotById(spreadId, slotId) == null) {
      throw PatchRejected(
        reason: PatchErrorCode.slotNotFound,
        message: 'slot "$slotId" not found in "$spreadId"',
        opIndex: index,
        operation: operation.op,
        details: <String, Object?>{'spreadId': spreadId, 'slotId': slotId},
      );
    }
  }

  static List<String> _spreadTargets(
    DesignDocument document,
    List<String>? spreadIds,
    PatchOperation operation,
    int index,
  ) {
    if (spreadIds == null) {
      return <String>[for (final spread in document.spreads) spread.id];
    }
    for (final spreadId in spreadIds) {
      if (document.spreadById(spreadId) == null) {
        throw PatchRejected(
          reason: PatchErrorCode.spreadNotFound,
          message: 'spread "$spreadId" not found',
          opIndex: index,
          operation: operation.op,
          details: <String, Object?>{'spreadId': spreadId},
        );
      }
    }
    return spreadIds;
  }

  static List<PreflightIssue> _newIssues({
    required PreflightReport before,
    required PreflightReport after,
  }) {
    final known = <String>{for (final issue in before.issues) _issueKey(issue)};
    return <PreflightIssue>[
      for (final issue in after.issues)
        if (!known.contains(_issueKey(issue))) issue,
    ];
  }

  static String _issueKey(PreflightIssue issue) =>
      '${issue.code.wire}|${issue.spreadId ?? ''}|${issue.slotId ?? ''}|'
      '${issue.photoId ?? ''}|${issue.targetId}';
}
