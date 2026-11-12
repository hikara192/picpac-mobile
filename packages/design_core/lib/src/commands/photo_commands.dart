import '../document/design_document.dart';
import '../document/photo_adjustment.dart';
import '../document/photo_asset.dart';
import '../document/slot.dart';
import '../document/spread.dart';
import 'command_result.dart';
import 'command_utils.dart';
import 'design_command.dart';

final class AddPhoto extends DesignCommand {
  const AddPhoto({required this.photo, this.index, this.spreadId, this.slotId});

  final PhotoAsset photo;

  final int? index;

  final String? spreadId;

  final String? slotId;

  @override
  String get kind => 'addPhoto';

  @override
  CommandResult validate(DesignDocument document) {
    if (document.assetById(photo.id) != null) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.duplicateId,
          message: 'photo "${photo.id}" is already in the document',
          targetId: photo.id,
        ),
      );
    }
    final at = index;
    if (at != null && (at < 0 || at > document.assets.length)) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidIndex,
          message: 'insert index $at is outside 0..${document.assets.length}',
          targetId: photo.id,
          args: <String, Object?>{'index': at},
        ),
      );
    }
    if ((spreadId == null) != (slotId == null)) {
      return const CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidTarget,
          message: 'spreadId and slotId must be provided together',
        ),
      );
    }
    final targetSpread = spreadId;
    final targetSlot = slotId;
    if (targetSpread != null && targetSlot != null) {
      final spread = document.spreadById(targetSpread);
      if (spread == null) {
        return CommandFailed(
          CommandError(
            code: CommandErrorCode.spreadNotFound,
            message: 'spread "$targetSpread" not found',
            targetId: targetSpread,
          ),
        );
      }
      final slot = spread.slotById(targetSlot);
      if (slot == null) {
        return CommandFailed(
          CommandError(
            code: CommandErrorCode.slotNotFound,
            message: 'slot "$targetSlot" not found in "$targetSpread"',
            targetId: targetSlot,
          ),
        );
      }
      if (slot.photoId != null) {
        return CommandFailed(
          CommandError(
            code: CommandErrorCode.slotOccupied,
            message: 'slot "$targetSlot" already holds "${slot.photoId}"',
            targetId: targetSlot,
          ),
        );
      }
    }
    return const CommandOk();
  }

  @override
  DesignDocument applyCore(DesignDocument document) {
    final assets = List<PhotoAsset>.of(document.assets)
      ..insert(index ?? document.assets.length, photo);
    var next = document.copyWith(assets: assets);
    final targetSpread = spreadId;
    final targetSlot = slotId;
    if (targetSpread != null && targetSlot != null) {
      next = assignSlotPhoto(next, targetSpread, targetSlot, photo.id);
    }
    return next;
  }

  @override
  DesignCommand invertCore(DesignDocument preState) =>
      RemovePhoto(photoId: photo.id);

  @override
  Map<String, Object?> describe() => <String, Object?>{
    'kind': kind,
    'photoId': photo.id,
    if (index != null) 'index': index,
    if (spreadId != null) 'spreadId': spreadId,
    if (slotId != null) 'slotId': slotId,
  };

  @override
  String toString() => 'AddPhoto(${photo.id})';
}

final class RemovePhoto extends DesignCommand {
  const RemovePhoto({required this.photoId});

  final String photoId;

  @override
  String get kind => 'removePhoto';

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
    return const CommandOk();
  }

  @override
  DesignDocument applyCore(DesignDocument document) {
    final assets = <PhotoAsset>[
      for (final asset in document.assets)
        if (asset.id != photoId) asset,
    ];
    final adjustments = Map<String, PhotoAdjustment>.of(
      document.photoAdjustments,
    )..remove(photoId);
    final spreads = <Spread>[
      for (final spread in document.spreads)
        spread.copyWith(
          slots: <Slot>[
            for (final slot in spread.slots)
              if (slot.photoId == photoId)
                slot.copyWith(photoId: null)
              else
                slot,
          ],
        ),
    ];
    return document.copyWith(
      assets: assets,
      photoAdjustments: adjustments,
      spreads: spreads,
    );
  }

  @override
  DesignCommand invertCore(DesignDocument preState) {
    final index = preState.assets.indexWhere((asset) => asset.id == photoId);
    return _RestorePhoto(
      asset: preState.assets[index],
      index: index,
      adjustment: preState.photoAdjustments[photoId],
      refs: preState.slotsForPhoto(photoId),
    );
  }

  @override
  Map<String, Object?> describe() => <String, Object?>{
    'kind': kind,
    'photoId': photoId,
  };

  @override
  String toString() => 'RemovePhoto($photoId)';
}

final class _RestorePhoto extends DesignCommand {
  const _RestorePhoto({
    required this.asset,
    required this.index,
    required this.refs,
    this.adjustment,
  });

  final PhotoAsset asset;
  final int index;
  final PhotoAdjustment? adjustment;
  final List<SlotRef> refs;

  @override
  String get kind => 'restorePhoto';

  @override
  CommandResult validate(DesignDocument document) {
    if (document.assetById(asset.id) != null) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.duplicateId,
          message: 'photo "${asset.id}" already exists',
          targetId: asset.id,
        ),
      );
    }
    if (index < 0 || index > document.assets.length) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidIndex,
          message:
              'restore index $index is outside 0..${document.assets.length}',
          targetId: asset.id,
        ),
      );
    }
    for (final ref in refs) {
      if (document.slotById(ref.spreadId, ref.slotId) == null) {
        return CommandFailed(
          CommandError(
            code: CommandErrorCode.slotNotFound,
            message: 'slot "${ref.slotId}" not found in "${ref.spreadId}"',
            targetId: ref.slotId,
          ),
        );
      }
    }
    return const CommandOk();
  }

  @override
  DesignDocument applyCore(DesignDocument document) {
    final assets = List<PhotoAsset>.of(document.assets)..insert(index, asset);
    var next = document.copyWith(
      assets: assets,
      photoAdjustments: adjustment == null
          ? document.photoAdjustments
          : <String, PhotoAdjustment>{
              ...document.photoAdjustments,
              asset.id: adjustment!,
            },
    );
    for (final ref in refs) {
      next = assignSlotPhoto(next, ref.spreadId, ref.slotId, asset.id);
    }
    return next;
  }

  @override
  DesignCommand invertCore(DesignDocument preState) =>
      RemovePhoto(photoId: asset.id);

  @override
  Map<String, Object?> describe() => <String, Object?>{
    'kind': kind,
    'photoId': asset.id,
    'index': index,
  };

  @override
  String toString() => 'RestorePhoto(${asset.id})';
}

final class ReorderPhotos extends DesignCommand {
  const ReorderPhotos({required this.fromIndex, required this.toIndex});

  final int fromIndex;

  final int toIndex;

  @override
  String get kind => 'reorderPhotos';

  @override
  CommandResult validate(DesignDocument document) {
    final length = document.assets.length;
    if (fromIndex < 0 || fromIndex >= length) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidIndex,
          message: 'fromIndex $fromIndex is outside 0..${length - 1}',
          args: <String, Object?>{'index': fromIndex},
        ),
      );
    }
    if (toIndex < 0 || toIndex >= length) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidIndex,
          message: 'toIndex $toIndex is outside 0..${length - 1}',
          args: <String, Object?>{'index': toIndex},
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
  DesignDocument applyCore(DesignDocument document) {
    final assets = moveItem(document.assets, fromIndex, toIndex);
    var next = document.copyWith(assets: assets);
    if (document.assets.isNotEmpty &&
        document.filledSlotCount == document.assets.length) {
      next = assignPhotoSequence(
        next,
        moveItem(document.orderedPhotoIds, fromIndex, toIndex),
      );
    }
    return next;
  }

  @override
  DesignCommand invertCore(DesignDocument preState) =>
      ReorderPhotos(fromIndex: toIndex, toIndex: fromIndex);

  @override
  Map<String, Object?> describe() => <String, Object?>{
    'kind': kind,
    'fromIndex': fromIndex,
    'toIndex': toIndex,
  };

  @override
  String toString() => 'ReorderPhotos($fromIndex → $toIndex)';
}
