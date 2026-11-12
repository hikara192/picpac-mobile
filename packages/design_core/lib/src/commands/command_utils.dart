import '../document/design_document.dart';
import '../document/slot.dart';
import '../document/spread.dart';

List<T> moveItem<T>(List<T> items, int from, int to) {
  final copy = List<T>.of(items);
  final item = copy.removeAt(from);
  copy.insert(to, item);
  return copy;
}

DesignDocument assignSlotPhoto(
  DesignDocument document,
  String spreadId,
  String slotId,
  String? photoId,
) {
  final spreads = <Spread>[];
  for (final spread in document.spreads) {
    if (spread.id != spreadId) {
      spreads.add(spread);
      continue;
    }
    spreads.add(
      spread.copyWith(
        slots: <Slot>[
          for (final slot in spread.slots)
            if (slot.id == slotId) slot.copyWith(photoId: photoId) else slot,
        ],
      ),
    );
  }
  return document.copyWith(spreads: spreads);
}

DesignDocument assignPhotoSequence(
  DesignDocument document,
  List<String> photoIds,
) {
  var index = 0;
  final spreads = <Spread>[];
  for (final spread in document.spreads) {
    final slots = <Slot>[];
    for (final slot in spread.slots) {
      if (slot.photoId == null || index >= photoIds.length) {
        slots.add(slot);
        continue;
      }
      slots.add(slot.copyWith(photoId: photoIds[index]));
      index++;
    }
    spreads.add(spread.copyWith(slots: slots));
  }
  return document.copyWith(spreads: spreads);
}

DesignDocument replaceSpread(
  DesignDocument document,
  String spreadId,
  Spread Function(Spread spread) update,
) => document.copyWith(
  spreads: <Spread>[
    for (final spread in document.spreads)
      if (spread.id == spreadId) update(spread) else spread,
  ],
);
