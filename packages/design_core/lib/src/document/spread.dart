import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../core/json_read.dart';
import '../document/design_format_exception.dart';
import 'slot.dart';

enum BackgroundType {
  color('color'),

  image('image'),

  gradient('gradient'),

  other('other');

  const BackgroundType(this.wire);

  final String wire;

  static BackgroundType fromWire(String raw) {
    for (final type in values) {
      if (type != BackgroundType.other && type.wire == raw) return type;
    }
    return BackgroundType.other;
  }
}

@immutable
final class SpreadBackground {
  const SpreadBackground({
    required this.type,
    required this.value,
    this.rawType,
  });

  factory SpreadBackground.color(String hex) =>
      SpreadBackground(type: BackgroundType.color, value: hex);

  final BackgroundType type;

  final String value;

  final String? rawType;

  bool get isColor => type == BackgroundType.color;

  int? get argbColor {
    if (!isColor) return null;
    final hex = value.startsWith('#') ? value.substring(1) : value;
    if (hex.length != 6 && hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return hex.length == 6 ? 0xFF000000 | parsed : parsed;
  }

  SpreadBackground copyWith({
    BackgroundType? type,
    String? value,
    String? rawType,
  }) => SpreadBackground(
    type: type ?? this.type,
    value: value ?? this.value,
    rawType: rawType ?? this.rawType,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'type': rawType ?? type.wire,
    'value': value,
  };

  factory SpreadBackground.fromJson(Object? json, String path) {
    final map = JsonRead.object(json, path);
    final rawType = JsonRead.id(map['type'], '$path.type');
    final type = BackgroundType.fromWire(rawType);
    final value = JsonRead.id(map['value'], '$path.value');
    if (type == BackgroundType.color &&
        int.tryParse(
              value.startsWith('#') ? value.substring(1) : value,
              radix: 16,
            ) ==
            null) {
      throw DesignFormatException(
        code: DesignFormatErrorCode.invalidValue,
        message: 'colour background expects a #RRGGBB value',
        path: '$path.value',
        args: <String, Object?>{'value': value},
      );
    }
    return SpreadBackground(
      type: type,
      value: value,
      rawType: type == BackgroundType.other ? rawType : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SpreadBackground &&
      other.type == type &&
      other.value == value &&
      other.rawType == rawType;

  @override
  int get hashCode => Object.hash(type, value, rawType);

  @override
  String toString() => 'SpreadBackground(${rawType ?? type.wire}: $value)';
}

@immutable
final class Spread {
  const Spread({
    required this.id,
    required this.templateId,
    required this.background,
    this.slots = const <Slot>[],
  });

  final String id;

  final String templateId;

  final SpreadBackground background;

  final List<Slot> slots;

  int get slotCount => slots.length;

  int get filledSlotCount => slots.where((s) => s.isFilled).length;

  int get emptySlotCount => slots.length - filledSlotCount;

  bool get hasEmptySlots => emptySlotCount > 0;

  bool get isComplete => slots.isNotEmpty && emptySlotCount == 0;

  Slot? slotById(String slotId) =>
      slots.firstWhereOrNull((slot) => slot.id == slotId);

  int indexOfSlot(String slotId) =>
      slots.indexWhere((slot) => slot.id == slotId);

  Spread copyWith({
    String? id,
    String? templateId,
    SpreadBackground? background,
    List<Slot>? slots,
  }) => Spread(
    id: id ?? this.id,
    templateId: templateId ?? this.templateId,
    background: background ?? this.background,
    slots: slots ?? this.slots,
  );

  Spread withSlot(Slot slot) {
    final index = indexOfSlot(slot.id);
    if (index < 0) {
      throw ArgumentError.value(slot.id, 'slot.id', 'unknown slot');
    }
    final next = <Slot>[...slots];
    next[index] = slot;
    return copyWith(slots: next);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'templateId': templateId,
    'background': background.toJson(),
    'slots': <Object?>[for (final slot in slots) slot.toJson()],
  };

  factory Spread.fromJson(Object? json, String path) {
    final map = JsonRead.object(json, path);
    final slotsJson = JsonRead.array(map['slots'], '$path.slots');
    final slots = <Slot>[
      for (var i = 0; i < slotsJson.length; i++)
        Slot.fromJson(slotsJson[i], '$path.slots[$i]'),
    ];
    final seen = <String>{};
    for (var i = 0; i < slots.length; i++) {
      if (!seen.add(slots[i].id)) {
        throw DesignFormatException(
          code: DesignFormatErrorCode.duplicateId,
          message: 'duplicate slot id "${slots[i].id}"',
          path: '$path.slots[$i].id',
        );
      }
    }
    return Spread(
      id: JsonRead.id(map['id'], '$path.id'),
      templateId: JsonRead.id(map['templateId'], '$path.templateId'),
      background: SpreadBackground.fromJson(
        map['background'],
        '$path.background',
      ),
      slots: slots,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Spread &&
      other.id == id &&
      other.templateId == templateId &&
      other.background == background &&
      const ListEquality<Slot>().equals(other.slots, slots);

  @override
  int get hashCode => Object.hash(
    id,
    templateId,
    background,
    const ListEquality<Slot>().hash(slots),
  );

  @override
  String toString() =>
      'Spread($id, template: $templateId, slots: $filledSlotCount/$slotCount)';
}
