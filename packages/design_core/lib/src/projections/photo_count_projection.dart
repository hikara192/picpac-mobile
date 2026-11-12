import 'package:meta/meta.dart';

import '../document/design_document.dart';

@immutable
final class PhotoCountProjection {
  const PhotoCountProjection({
    required this.spreadCount,
    required this.slotCount,
    required this.filledSlotCount,
    required this.photoCount,
    required this.usedPhotoCount,
    required this.unusedPhotoCount,
    required this.spreadsWithEmptySlots,
  });

  factory PhotoCountProjection.from(DesignDocument document) {
    var slotCount = 0;
    var filled = 0;
    var spreadsWithEmptySlots = 0;
    for (final spread in document.spreads) {
      slotCount += spread.slotCount;
      filled += spread.filledSlotCount;
      if (spread.hasEmptySlots) spreadsWithEmptySlots++;
    }
    final used = document.usedPhotoIds.length;
    return PhotoCountProjection(
      spreadCount: document.spreads.length,
      slotCount: slotCount,
      filledSlotCount: filled,
      photoCount: document.photoCount,
      usedPhotoCount: used,
      unusedPhotoCount: document.photoCount - used,
      spreadsWithEmptySlots: spreadsWithEmptySlots,
    );
  }

  final int spreadCount;

  final int slotCount;

  final int filledSlotCount;

  final int photoCount;

  final int usedPhotoCount;

  final int unusedPhotoCount;

  final int spreadsWithEmptySlots;

  int get emptySlotCount => slotCount - filledSlotCount;

  bool get isComplete => slotCount > 0 && emptySlotCount == 0;

  bool get hasGaps => emptySlotCount > 0;

  Map<String, Object?> toJson() => <String, Object?>{
    'spreadCount': spreadCount,
    'slotCount': slotCount,
    'filledSlotCount': filledSlotCount,
    'photoCount': photoCount,
    'usedPhotoCount': usedPhotoCount,
    'unusedPhotoCount': unusedPhotoCount,
    'spreadsWithEmptySlots': spreadsWithEmptySlots,
  };

  @override
  String toString() =>
      'PhotoCountProjection($filledSlotCount/$slotCount slots, '
      '$photoCount photos)';
}
