import 'package:meta/meta.dart';

import '../core/json_read.dart';
import 'design_format_exception.dart';
import 'geometry.dart';

enum TextAlign {
  left('left'),

  center('center'),

  right('right'),

  unknown('unknown');

  const TextAlign(this.wire);

  final String wire;

  static TextAlign fromWire(String raw) {
    for (final value in values) {
      if (value != TextAlign.unknown && value.wire == raw) return value;
    }
    return TextAlign.unknown;
  }
}

@immutable
final class TextElement {
  const TextElement({
    required this.id,
    required this.spreadId,
    required this.text,
    required this.box,
    this.fontSizeNorm = defaultFontSizeNorm,
    this.align = TextAlign.center,
    this.styleKey = defaultStyleKey,
    this.colorHex,
  });

  static const double defaultFontSizeNorm = 0.045;

  static const double minFontSizeNorm = 0.01;

  static const double maxFontSizeNorm = 0.5;

  static const String defaultStyleKey = 'body';

  static const int maxTextLength = 2000;

  final String id;

  final String spreadId;

  final String text;

  final NormalizedRect box;

  final double fontSizeNorm;

  final TextAlign align;

  final String styleKey;

  final String? colorHex;

  bool get isBlank => text.trim().isEmpty;

  TextElement clamped() => TextElement(
    id: id,
    spreadId: spreadId,
    text: text.length > maxTextLength ? text.substring(0, maxTextLength) : text,
    box: box.clamped(),
    fontSizeNorm: fontSizeNorm
        .clamp(minFontSizeNorm, maxFontSizeNorm)
        .toDouble(),
    align: align,
    styleKey: styleKey,
    colorHex: colorHex,
  );

  TextElement copyWith({
    String? id,
    String? spreadId,
    String? text,
    NormalizedRect? box,
    double? fontSizeNorm,
    TextAlign? align,
    String? styleKey,
    String? colorHex,
  }) => TextElement(
    id: id ?? this.id,
    spreadId: spreadId ?? this.spreadId,
    text: text ?? this.text,
    box: box ?? this.box,
    fontSizeNorm: fontSizeNorm ?? this.fontSizeNorm,
    align: align ?? this.align,
    styleKey: styleKey ?? this.styleKey,
    colorHex: colorHex ?? this.colorHex,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'spreadId': spreadId,
    'text': text,
    'box': box.toJson(),
    'fontSizeNorm': fontSizeNorm,
    'align': align.wire,
    'styleKey': styleKey,
    if (colorHex != null) 'colorHex': colorHex,
  };

  factory TextElement.fromJson(Object? json, String path) {
    final map = JsonRead.object(json, path);
    final text = JsonRead.string(map['text'], '$path.text');
    if (text.length > maxTextLength) {
      throw DesignFormatException(
        code: DesignFormatErrorCode.outOfRange,
        message: 'text exceeds $maxTextLength characters',
        path: '$path.text',
      );
    }
    final fontSize = JsonRead.optNumber(
      map['fontSizeNorm'],
      '$path.fontSizeNorm',
    );
    if (fontSize != null &&
        (fontSize < minFontSizeNorm || fontSize > maxFontSizeNorm)) {
      throw DesignFormatException(
        code: DesignFormatErrorCode.outOfRange,
        message:
            'fontSizeNorm must be within $minFontSizeNorm..$maxFontSizeNorm, '
            'got $fontSize',
        path: '$path.fontSizeNorm',
      );
    }
    final rawAlign = map['align'];
    return TextElement(
      id: JsonRead.id(map['id'], '$path.id'),
      spreadId: JsonRead.id(map['spreadId'], '$path.spreadId'),
      text: text,
      box: NormalizedRect.fromJson(map['box'], '$path.box'),
      fontSizeNorm: fontSize ?? defaultFontSizeNorm,
      align: rawAlign == null
          ? TextAlign.center
          : TextAlign.fromWire(JsonRead.string(rawAlign, '$path.align')),
      styleKey:
          JsonRead.optId(map['styleKey'], '$path.styleKey') ?? defaultStyleKey,
      colorHex: JsonRead.optId(map['colorHex'], '$path.colorHex'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TextElement &&
      other.id == id &&
      other.spreadId == spreadId &&
      other.text == text &&
      other.box == box &&
      other.fontSizeNorm == fontSizeNorm &&
      other.align == align &&
      other.styleKey == styleKey &&
      other.colorHex == colorHex;

  @override
  int get hashCode => Object.hash(
    id,
    spreadId,
    text,
    box,
    fontSizeNorm,
    align,
    styleKey,
    colorHex,
  );

  @override
  String toString() => 'TextElement($id on $spreadId, "$text")';
}
