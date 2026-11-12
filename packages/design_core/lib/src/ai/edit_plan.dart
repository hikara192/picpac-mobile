import 'package:meta/meta.dart';

import '../document/adjustment_limits.dart';
import '../document/design_document.dart';
import '../document/look_library.dart';
import '../document/spread.dart';
import 'design_patch.dart';

@immutable
final class EditPlanEntry {
  const EditPlanEntry({
    required this.code,
    required this.messageKey,
    this.args = const <String, Object?>{},
    this.opIndex,
    this.removesPhoto = false,
    this.changesComposition = false,
  });

  final String code;

  final String messageKey;

  final Map<String, Object?> args;

  final int? opIndex;

  final bool removesPhoto;

  final bool changesComposition;

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'messageKey': messageKey,
    if (args.isNotEmpty) 'args': args,
    if (opIndex != null) 'opIndex': opIndex,
    if (removesPhoto) 'removesPhoto': true,
    if (changesComposition) 'changesComposition': true,
  };

  @override
  String toString() =>
      'EditPlanEntry($code → $messageKey${args.isEmpty ? '' : ', $args'})';
}

@immutable
final class EditPlan {
  const EditPlan(this.entries);

  static const EditPlan empty = EditPlan(<EditPlanEntry>[]);

  final List<EditPlanEntry> entries;

  bool get isEmpty => entries.isEmpty;

  bool get removesPhotos => entries.any((entry) => entry.removesPhoto);

  bool get changesComposition =>
      entries.any((entry) => entry.changesComposition);

  int get length => entries.length;

  factory EditPlan.of(DesignPatch patch, DesignDocument document) {
    final entries = <EditPlanEntry>[];
    for (var index = 0; index < patch.operations.length; index++) {
      final entry = _entryOf(patch.operations[index], document, index);
      if (entry != null) entries.add(entry);
    }
    return EditPlan(List<EditPlanEntry>.unmodifiable(entries));
  }

  static EditPlanEntry? _entryOf(
    PatchOperation operation,
    DesignDocument document,
    int index,
  ) => switch (operation) {
    SetCropOperation() => EditPlanEntry(
      code: 'framing',
      messageKey: 'aiChangeFraming',
      args: <String, Object?>{'count': 1},
      opIndex: index,
    ),
    SetAdjustmentOperation(:final field, :final value, :final photoIds) =>
      EditPlanEntry(
        code: 'tone',
        messageKey: 'aiChangeTone',
        args: <String, Object?>{
          'count': photoIds?.length ?? document.photoCount,
          'field': field.wire,
          'labelKey': AdjustmentLimits.of(field).labelKey,
          'value': value,
          'direction': value >= 0 ? 'up' : 'down',
        },
        opIndex: index,
      ),
    ApplyLookOperation(:final lookId, :final strength, :final photoIds) =>
      EditPlanEntry(
        code: 'look',
        messageKey: 'aiChangeLook',
        args: <String, Object?>{
          'count': photoIds?.length ?? document.photoCount,
          'lookId': lookId,
          'nameKey': LookLibrary.byId(lookId)?.nameKey ?? lookId,
          'strength': strength,
        },
        opIndex: index,
        changesComposition: false,
      ),
    AssignPhotoOperation(:final photoId) => EditPlanEntry(
      code: photoId == null ? 'clearSlot' : 'assign',
      messageKey: photoId == null ? 'aiChangeClearSlot' : 'aiChangeAssignPhoto',
      args: const <String, Object?>{'count': 1},
      opIndex: index,
      removesPhoto: photoId == null,
      changesComposition: true,
    ),
    ReplacePhotoOperation() => EditPlanEntry(
      code: 'replace',
      messageKey: 'aiChangeReplacePhoto',
      args: const <String, Object?>{'count': 1},
      opIndex: index,
      changesComposition: true,
    ),
    SetBackgroundOperation(:final type, :final spreadIds) => EditPlanEntry(
      code: 'background',
      messageKey: 'aiChangeBackground',
      args: <String, Object?>{
        'count': spreadIds?.length ?? document.spreads.length,
        'isColor': type == BackgroundType.color,
      },
      opIndex: index,
    ),
    SetLayoutOperation(:final templateId, :final spreadIds) => EditPlanEntry(
      code: 'layout',
      messageKey: 'aiChangeLayout',
      args: <String, Object?>{
        'count': spreadIds?.length ?? document.spreads.length,
        'templateId': templateId,
      },
      opIndex: index,
      changesComposition: true,
    ),
    SwapSlotsOperation() => EditPlanEntry(
      code: 'swap',
      messageKey: 'aiChangeSwap',
      args: const <String, Object?>{'count': 1},
      opIndex: index,
      changesComposition: true,
    ),
  };
}
