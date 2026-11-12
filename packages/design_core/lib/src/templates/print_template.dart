import 'package:meta/meta.dart';

import '../core/json_read.dart';
import '../core/result.dart';
import '../document/design_format_exception.dart';
import '../document/geometry.dart';

enum TemplateKind {
  print('print'),

  collage('collage'),

  spread('spread'),

  cover('cover'),

  page('page'),

  other('other');

  const TemplateKind(this.wire);

  final String wire;

  static TemplateKind fromWire(String raw) {
    for (final value in values) {
      if (value != TemplateKind.other && value.wire == raw) return value;
    }
    return TemplateKind.other;
  }
}

@immutable
final class TemplateSlot {
  const TemplateSlot({
    required this.id,
    required this.rect,
    this.safeInset = 0,
  });

  final String id;

  final NormalizedRect rect;

  final double safeInset;

  TemplateSlot copyWith({
    String? id,
    NormalizedRect? rect,
    double? safeInset,
  }) => TemplateSlot(
    id: id ?? this.id,
    rect: rect ?? this.rect,
    safeInset: safeInset ?? this.safeInset,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'rect': rect.toJson(),
    'safeInset': safeInset,
  };

  factory TemplateSlot.fromJson(Object? json, String path) {
    final map = JsonRead.object(json, path);
    final safeInset =
        JsonRead.optNumber(map['safeInset'], '$path.safeInset') ?? 0;
    if (safeInset < 0 || safeInset >= 0.5) {
      throw DesignFormatException(
        code: DesignFormatErrorCode.outOfRange,
        message: 'safeInset must be within 0..0.5, got $safeInset',
        path: '$path.safeInset',
      );
    }
    return TemplateSlot(
      id: JsonRead.id(map['id'], '$path.id'),
      rect: NormalizedRect.fromJson(map['rect'], '$path.rect'),
      safeInset: safeInset,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TemplateSlot &&
      other.id == id &&
      other.rect == rect &&
      other.safeInset == safeInset;

  @override
  int get hashCode => Object.hash(id, rect, safeInset);

  @override
  String toString() => 'TemplateSlot($id, $rect)';
}

@immutable
final class PrintTemplate {
  const PrintTemplate({
    required this.id,
    required this.nameKey,
    required this.kind,
    required this.slots,
    this.aspect = 1,
  });

  final String id;

  final String nameKey;

  final TemplateKind kind;

  final List<TemplateSlot> slots;

  final double aspect;

  int get slotCount => slots.length;

  bool get isSingleSlot => slots.length == 1;

  TemplateSlot? slotById(String slotId) {
    for (final slot in slots) {
      if (slot.id == slotId) return slot;
    }
    return null;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'nameKey': nameKey,
    'kind': kind.wire,
    'aspect': aspect,
    'slots': <Object?>[for (final slot in slots) slot.toJson()],
  };

  static Result<PrintTemplate> fromJson(Object? json) {
    try {
      return Ok<PrintTemplate>(fromJsonOrThrow(json));
    } on DesignFormatException catch (error) {
      return Err<PrintTemplate>(error);
    }
  }

  static PrintTemplate fromJsonOrThrow(Object? json) {
    final map = JsonRead.object(json, r'$');
    final slotsJson = JsonRead.array(map['slots'], r'$.slots');
    if (slotsJson.isEmpty) {
      throw const DesignFormatException(
        code: DesignFormatErrorCode.invalidValue,
        message: 'template must contain at least one slot',
        path: r'$.slots',
      );
    }
    final slots = <TemplateSlot>[
      for (var i = 0; i < slotsJson.length; i++)
        TemplateSlot.fromJson(slotsJson[i], '\$.slots[$i]'),
    ];
    final seen = <String>{};
    for (var i = 0; i < slots.length; i++) {
      if (!seen.add(slots[i].id)) {
        throw DesignFormatException(
          code: DesignFormatErrorCode.duplicateId,
          message: 'duplicate slot id "${slots[i].id}"',
          path: '\$.slots[$i].id',
        );
      }
    }
    final aspect = JsonRead.optNumber(map['aspect'], r'$.aspect') ?? 1;
    if (aspect <= 0) {
      throw const DesignFormatException(
        code: DesignFormatErrorCode.outOfRange,
        message: 'aspect must be positive',
        path: r'$.aspect',
      );
    }
    final rawKind = map['kind'];
    return PrintTemplate(
      id: JsonRead.id(map['id'], r'$.id'),
      nameKey: JsonRead.id(map['nameKey'], r'$.nameKey'),
      kind: rawKind == null
          ? TemplateKind.other
          : TemplateKind.fromWire(JsonRead.string(rawKind, r'$.kind')),
      slots: List<TemplateSlot>.unmodifiable(slots),
      aspect: aspect,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PrintTemplate &&
      other.id == id &&
      other.nameKey == nameKey &&
      other.kind == kind &&
      other.aspect == aspect &&
      other.slots.length == slots.length &&
      <int>[for (var i = 0; i < slots.length; i++) i]
          .every((i) => other.slots[i] == slots[i]);

  @override
  int get hashCode =>
      Object.hash(id, nameKey, kind, aspect, Object.hashAll(slots));

  @override
  String toString() => 'PrintTemplate($id, ${slots.length} slots)';
}
