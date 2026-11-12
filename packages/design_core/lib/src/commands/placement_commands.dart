import '../document/design_document.dart';
import '../document/geometry.dart';
import '../document/slot.dart';
import '../document/spread.dart';
import '../templates/print_template.dart';
import 'command_result.dart';
import 'command_utils.dart';
import 'design_command.dart';

final class SetCrop extends DesignCommand {
  const SetCrop({
    required this.spreadId,
    required this.slotId,
    required this.crop,
    this.zoom,
    this.anchor,
  });

  final String spreadId;

  final String slotId;

  final Crop crop;

  final double? zoom;

  final NormalizedPoint? anchor;

  @override
  String get kind => 'setCrop';

  @override
  CommandResult validate(DesignDocument document) {
    final spread = document.spreadById(spreadId);
    if (spread == null) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.spreadNotFound,
          message: 'spread "$spreadId" not found',
          targetId: spreadId,
        ),
      );
    }
    if (spread.slotById(slotId) == null) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.slotNotFound,
          message: 'slot "$slotId" not found in "$spreadId"',
          targetId: slotId,
        ),
      );
    }
    final nextZoom = zoom;
    if (nextZoom != null &&
        (!nextZoom.isFinite ||
            nextZoom < Slot.minZoom ||
            nextZoom > Slot.maxZoom)) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidValue,
          message: 'zoom must be within ${Slot.minZoom}..${Slot.maxZoom}',
          targetId: slotId,
          args: <String, Object?>{'zoom': nextZoom},
        ),
      );
    }
    final nextAnchor = anchor;
    if (nextAnchor != null && !nextAnchor.isInsideUnitSquare) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidValue,
          message: 'anchor must be inside 0..1',
          targetId: slotId,
          args: <String, Object?>{'anchor': nextAnchor.toJson()},
        ),
      );
    }
    if (!crop.w.isFinite ||
        !crop.h.isFinite ||
        !crop.x.isFinite ||
        !crop.y.isFinite) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidValue,
          message: 'crop must contain finite numbers',
          targetId: slotId,
        ),
      );
    }
    return const CommandOk();
  }

  @override
  DesignDocument applyCore(DesignDocument document) {
    final spread = document.spreadById(spreadId)!;
    final slot = spread.slotById(slotId)!;
    final next = slot.copyWith(
      crop: crop.clamped(),
      zoom: zoom,
      anchor: anchor?.clamped(),
    );
    return replaceSpread(document, spreadId, (spread) => spread.withSlot(next));
  }

  @override
  DesignCommand invertCore(DesignDocument preState) {
    final slot = preState.slotById(spreadId, slotId)!;
    return SetCrop(
      spreadId: spreadId,
      slotId: slotId,
      crop: slot.crop,
      zoom: slot.zoom,
      anchor: slot.anchor,
    );
  }

  @override
  Map<String, Object?> describe() => <String, Object?>{
    'kind': kind,
    'spreadId': spreadId,
    'slotId': slotId,
    'crop': crop.toJson(),
    if (zoom != null) 'zoom': zoom,
    if (anchor != null) 'anchor': anchor!.toJson(),
  };

  @override
  String toString() => 'SetCrop($spreadId/$slotId)';
}

final class AssignPhoto extends DesignCommand {
  const AssignPhoto({
    required this.spreadId,
    required this.slotId,
    required this.photoId,
  });

  final String spreadId;

  final String slotId;

  final String? photoId;

  @override
  String get kind => 'assignPhoto';

  @override
  CommandResult validate(DesignDocument document) {
    final spread = document.spreadById(spreadId);
    if (spread == null) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.spreadNotFound,
          message: 'spread "$spreadId" not found',
          targetId: spreadId,
        ),
      );
    }
    if (spread.slotById(slotId) == null) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.slotNotFound,
          message: 'slot "$slotId" not found in "$spreadId"',
          targetId: slotId,
        ),
      );
    }
    final photo = photoId;
    if (photo != null && document.assetById(photo) == null) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.photoNotInDocument,
          message: 'photo "$photo" is not in the document',
          targetId: photo,
        ),
      );
    }
    return const CommandOk();
  }

  @override
  DesignDocument applyCore(DesignDocument document) =>
      assignSlotPhoto(document, spreadId, slotId, photoId);

  @override
  DesignCommand invertCore(DesignDocument preState) => AssignPhoto(
    spreadId: spreadId,
    slotId: slotId,
    photoId: preState.slotById(spreadId, slotId)!.photoId,
  );

  @override
  Map<String, Object?> describe() => <String, Object?>{
    'kind': kind,
    'spreadId': spreadId,
    'slotId': slotId,
    'photoId': photoId,
  };

  @override
  String toString() => 'AssignPhoto($spreadId/$slotId → $photoId)';
}

final class SetLayout extends DesignCommand {
  const SetLayout({required this.spreadId, required this.template});

  final String spreadId;

  final PrintTemplate template;

  @override
  String get kind => 'setLayout';

  @override
  CommandResult validate(DesignDocument document) {
    if (document.spreadById(spreadId) == null) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.spreadNotFound,
          message: 'spread "$spreadId" not found',
          targetId: spreadId,
        ),
      );
    }
    if (template.slots.isEmpty) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidTarget,
          message: 'template "${template.id}" has no slots',
          targetId: template.id,
        ),
      );
    }
    final seen = <String>{};
    for (final slot in template.slots) {
      if (!seen.add(slot.id)) {
        return CommandFailed(
          CommandError(
            code: CommandErrorCode.duplicateId,
            message:
                'template "${template.id}" has duplicate slot "${slot.id}"',
            targetId: slot.id,
          ),
        );
      }
    }
    return const CommandOk();
  }

  @override
  DesignDocument applyCore(DesignDocument document) {
    final spread = document.spreadById(spreadId)!;
    final slots = <Slot>[
      for (final templateSlot in template.slots)
        spread.slotById(templateSlot.id) ?? Slot(id: templateSlot.id),
    ];
    return replaceSpread(
      document,
      spreadId,
      (spread) => spread.copyWith(templateId: template.id, slots: slots),
    );
  }

  @override
  DesignCommand invertCore(DesignDocument preState) {
    final spread = preState.spreadById(spreadId)!;
    return _RestoreSpreadLayout(
      spreadId: spreadId,
      templateId: spread.templateId,
      slots: spread.slots,
    );
  }

  @override
  Map<String, Object?> describe() => <String, Object?>{
    'kind': kind,
    'spreadId': spreadId,
    'templateId': template.id,
  };

  @override
  String toString() => 'SetLayout($spreadId → ${template.id})';
}

final class _RestoreSpreadLayout extends DesignCommand {
  const _RestoreSpreadLayout({
    required this.spreadId,
    required this.templateId,
    required this.slots,
  });

  final String spreadId;
  final String templateId;
  final List<Slot> slots;

  @override
  String get kind => 'restoreLayout';

  @override
  CommandResult validate(DesignDocument document) {
    if (document.spreadById(spreadId) == null) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.spreadNotFound,
          message: 'spread "$spreadId" not found',
          targetId: spreadId,
        ),
      );
    }
    return const CommandOk();
  }

  @override
  DesignDocument applyCore(DesignDocument document) => replaceSpread(
    document,
    spreadId,
    (spread) => spread.copyWith(templateId: templateId, slots: slots),
  );

  @override
  DesignCommand invertCore(DesignDocument preState) {
    final spread = preState.spreadById(spreadId)!;
    return _RestoreSpreadLayout(
      spreadId: spreadId,
      templateId: spread.templateId,
      slots: spread.slots,
    );
  }

  @override
  Map<String, Object?> describe() => <String, Object?>{
    'kind': kind,
    'spreadId': spreadId,
    'templateId': templateId,
  };
}

final class ReorderSpreads extends DesignCommand {
  const ReorderSpreads({required this.fromIndex, required this.toIndex});

  final int fromIndex;

  final int toIndex;

  @override
  String get kind => 'reorderSpreads';

  @override
  CommandResult validate(DesignDocument document) {
    final length = document.spreads.length;
    if (fromIndex < 0 ||
        fromIndex >= length ||
        toIndex < 0 ||
        toIndex >= length) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidIndex,
          message: 'indices $fromIndex → $toIndex are outside 0..${length - 1}',
          args: <String, Object?>{'from': fromIndex, 'to': toIndex},
        ),
      );
    }
    if (fromIndex == toIndex) {
      return const CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidTarget,
          message: 'fromIndex and toIndex are equal',
        ),
      );
    }
    return const CommandOk();
  }

  @override
  DesignDocument applyCore(DesignDocument document) => document.copyWith(
    spreads: moveItem(document.spreads, fromIndex, toIndex),
  );

  @override
  DesignCommand invertCore(DesignDocument preState) =>
      ReorderSpreads(fromIndex: toIndex, toIndex: fromIndex);

  @override
  Map<String, Object?> describe() => <String, Object?>{
    'kind': kind,
    'fromIndex': fromIndex,
    'toIndex': toIndex,
  };

  @override
  String toString() => 'ReorderSpreads($fromIndex → $toIndex)';
}

final class SetCover extends DesignCommand {
  const SetCover({required this.spreadId});

  final String? spreadId;

  @override
  String get kind => 'setCover';

  @override
  CommandResult validate(DesignDocument document) {
    final id = spreadId;
    if (id != null && document.spreadById(id) == null) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.spreadNotFound,
          message: 'spread "$id" not found',
          targetId: id,
        ),
      );
    }
    return const CommandOk();
  }

  @override
  DesignDocument applyCore(DesignDocument document) =>
      document.copyWith(coverSpreadId: spreadId);

  @override
  DesignCommand invertCore(DesignDocument preState) =>
      SetCover(spreadId: preState.coverSpreadId);

  @override
  Map<String, Object?> describe() => <String, Object?>{
    'kind': kind,
    'spreadId': spreadId,
  };

  @override
  String toString() => 'SetCover($spreadId)';
}

final class SetBackground extends DesignCommand {
  const SetBackground({required this.spreadId, required this.background});

  final String spreadId;

  final SpreadBackground background;

  @override
  String get kind => 'setBackground';

  @override
  CommandResult validate(DesignDocument document) {
    if (document.spreadById(spreadId) == null) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.spreadNotFound,
          message: 'spread "$spreadId" not found',
          targetId: spreadId,
        ),
      );
    }
    return const CommandOk();
  }

  @override
  DesignDocument applyCore(DesignDocument document) => replaceSpread(
    document,
    spreadId,
    (spread) => spread.copyWith(background: background),
  );

  @override
  DesignCommand invertCore(DesignDocument preState) => SetBackground(
    spreadId: spreadId,
    background: preState.spreadById(spreadId)!.background,
  );

  @override
  Map<String, Object?> describe() => <String, Object?>{
    'kind': kind,
    'spreadId': spreadId,
    'background': background.toJson(),
  };

  @override
  String toString() => 'SetBackground($spreadId → $background)';
}
