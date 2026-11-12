import '../document/design_document.dart';
import '../document/look_library.dart';
import '../document/photo_adjustment.dart';
import 'command_result.dart';
import 'design_command.dart';

final class SetPhotoAdjustment extends DesignCommand {
  const SetPhotoAdjustment({
    required this.photoId,
    required this.field,
    required this.value,
  });

  final String photoId;

  final PhotoAdjustmentField field;

  final double value;

  @override
  String get kind => 'setPhotoAdjustment';

  @override
  CommandResult validate(DesignDocument document) {
    if (document.assetById(photoId) == null) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.photoNotInDocument,
          message: 'photo "$photoId" is not in the document',
          targetId: photoId,
        ),
      );
    }
    if (!value.isFinite) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidValue,
          message: '${field.wire} must be a finite number',
          targetId: photoId,
          args: <String, Object?>{'field': field.wire, 'value': '$value'},
        ),
      );
    }
    return const CommandOk();
  }

  @override
  DesignDocument applyCore(DesignDocument document) {
    final current =
        document.photoAdjustments[photoId] ?? PhotoAdjustment.neutral;
    final next = current.withField(field, value);
    return _withAdjustment(document, photoId, next);
  }

  @override
  bool coalesce(DesignCommand next) =>
      next is SetPhotoAdjustment &&
      next.photoId == photoId &&
      next.field == field;

  @override
  DesignCommand invertCore(DesignDocument preState) => _RestoreAdjustment(
    photoId: photoId,
    adjustment: preState.photoAdjustments[photoId],
  );

  @override
  Map<String, Object?> describe() => <String, Object?>{
    'kind': kind,
    'photoId': photoId,
    'field': field.wire,
    'value': value,
  };

  @override
  String toString() => 'SetPhotoAdjustment($photoId.${field.wire} = $value)';
}

final class SetLook extends DesignCommand {
  const SetLook({required this.photoId, required this.look});

  final String photoId;

  final LookSetting? look;

  @override
  String get kind => 'setLook';

  @override
  CommandResult validate(DesignDocument document) {
    if (document.assetById(photoId) == null) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.photoNotInDocument,
          message: 'photo "$photoId" is not in the document',
          targetId: photoId,
        ),
      );
    }
    final value = look;
    if (value != null) {
      if (value.id.trim().isEmpty) {
        return CommandFailed(
          CommandError(
            code: CommandErrorCode.invalidValue,
            message: 'look id must not be empty',
            targetId: photoId,
          ),
        );
      }
      if (!LookLibrary.containsId(value.id)) {
        return CommandFailed(
          CommandError(
            code: CommandErrorCode.invalidValue,
            message:
                'unknown look "${value.id}" (library v${LookLibrary.version})',
            targetId: photoId,
            args: <String, Object?>{
              'lookId': value.id,
              'allowed': LookLibrary.ids.join(', '),
            },
          ),
        );
      }
      if (!value.strength.isFinite ||
          value.strength < AdjustmentLimits.lookStrength.min ||
          value.strength > AdjustmentLimits.lookStrength.max) {
        return CommandFailed(
          CommandError(
            code: CommandErrorCode.invalidValue,
            message:
                'look strength must be within '
                '${AdjustmentLimits.lookStrength.min}..'
                '${AdjustmentLimits.lookStrength.max}',
            targetId: photoId,
            args: <String, Object?>{'strength': value.strength},
          ),
        );
      }
    }
    return const CommandOk();
  }

  @override
  DesignDocument applyCore(DesignDocument document) {
    final current =
        document.photoAdjustments[photoId] ?? PhotoAdjustment.neutral;
    return _withAdjustment(document, photoId, current.withLook(look));
  }

  @override
  DesignCommand invertCore(DesignDocument preState) => _RestoreAdjustment(
    photoId: photoId,
    adjustment: preState.photoAdjustments[photoId],
  );

  @override
  Map<String, Object?> describe() => <String, Object?>{
    'kind': kind,
    'photoId': photoId,
    if (look != null) 'lookId': look!.id,
    if (look != null) 'strength': look!.strength,
  };

  @override
  String toString() => 'SetLook($photoId → ${look?.id})';
}

final class ApplyLook extends DesignCommand {
  const ApplyLook({
    required this.photoIds,
    required this.lookId,
    required this.strength,
  });

  final List<String> photoIds;

  final String lookId;

  final double strength;

  @override
  String get kind => 'applyLook';

  @override
  CommandResult validate(DesignDocument document) {
    if (photoIds.isEmpty) {
      return const CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidTarget,
          message: 'applyLook requires at least one photo',
        ),
      );
    }
    for (final photoId in photoIds) {
      if (document.assetById(photoId) == null) {
        return CommandFailed(
          CommandError(
            code: CommandErrorCode.photoNotInDocument,
            message: 'photo "$photoId" is not in the document',
            targetId: photoId,
          ),
        );
      }
    }
    if (lookId.trim().isEmpty) {
      return const CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidValue,
          message: 'look id must not be empty',
        ),
      );
    }
    if (!LookLibrary.containsId(lookId)) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidValue,
          message: 'unknown look "$lookId" (library v${LookLibrary.version})',
          args: <String, Object?>{
            'lookId': lookId,
            'allowed': LookLibrary.ids.join(', '),
          },
        ),
      );
    }
    if (!strength.isFinite ||
        strength < AdjustmentLimits.lookStrength.min ||
        strength > AdjustmentLimits.lookStrength.max) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidValue,
          message:
              'look strength must be within '
              '${AdjustmentLimits.lookStrength.min}..'
              '${AdjustmentLimits.lookStrength.max}',
          args: <String, Object?>{'strength': strength},
        ),
      );
    }
    return const CommandOk();
  }

  @override
  DesignDocument applyCore(DesignDocument document) {
    final clamped = AdjustmentLimits.clampStrength(strength);
    final preset = LookLibrary.byId(lookId);
    var next = document;
    for (final photoId in photoIds) {
      final current = next.photoAdjustments[photoId] ?? PhotoAdjustment.neutral;
      next = _withAdjustment(
        next,
        photoId,
        current.withLook(
          clamped <= 0 || preset == null || preset.isNeutral
              ? null
              : LookSetting(id: lookId, strength: clamped),
        ),
      );
    }
    return next;
  }

  @override
  DesignCommand invertCore(DesignDocument preState) =>
      CompositeCommand(<DesignCommand>[
        for (final photoId in photoIds)
          _RestoreAdjustment(
            photoId: photoId,
            adjustment: preState.photoAdjustments[photoId],
          ),
      ], label: 'undo:applyLook');

  @override
  Map<String, Object?> describe() => <String, Object?>{
    'kind': kind,
    'photoIds': photoIds,
    'lookId': lookId,
    'strength': strength,
  };

  @override
  String toString() => 'ApplyLook($lookId × ${photoIds.length})';
}

final class _RestoreAdjustment extends DesignCommand {
  const _RestoreAdjustment({required this.photoId, this.adjustment});

  final String photoId;
  final PhotoAdjustment? adjustment;

  @override
  String get kind => 'restoreAdjustment';

  @override
  CommandResult validate(DesignDocument document) => const CommandOk();

  @override
  DesignDocument applyCore(DesignDocument document) {
    final value = adjustment;
    if (value == null) {
      if (!document.photoAdjustments.containsKey(photoId)) return document;
      return document.copyWith(
        photoAdjustments: Map<String, PhotoAdjustment>.of(
          document.photoAdjustments,
        )..remove(photoId),
      );
    }
    return document.copyWith(
      photoAdjustments: <String, PhotoAdjustment>{
        ...document.photoAdjustments,
        photoId: value,
      },
    );
  }

  @override
  DesignCommand invertCore(DesignDocument preState) => _RestoreAdjustment(
    photoId: photoId,
    adjustment: preState.photoAdjustments[photoId],
  );

  @override
  Map<String, Object?> describe() => <String, Object?>{
    'kind': kind,
    'photoId': photoId,
  };
}

DesignDocument _withAdjustment(
  DesignDocument document,
  String photoId,
  PhotoAdjustment adjustment,
) {
  final map = Map<String, PhotoAdjustment>.of(document.photoAdjustments);
  if (adjustment.isNeutral) {
    map.remove(photoId);
  } else {
    map[photoId] = adjustment;
  }
  return document.copyWith(photoAdjustments: map);
}
