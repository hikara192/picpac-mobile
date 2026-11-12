import 'dart:math' as math;

import '../document/design_document.dart';
import '../document/geometry.dart';
import '../document/print_spec.dart';
import '../document/text_element.dart';

class TextExtent {
  const TextExtent({
    required this.lineCount,
    required this.requiredHeightMm,
    required this.availableHeightMm,
    required this.exceedsBox,
  });

  final int lineCount;

  final double requiredHeightMm;

  final double availableHeightMm;

  final bool exceedsBox;

  @override
  String toString() =>
      'TextExtent($lineCount lines, ${requiredHeightMm.toStringAsFixed(1)} / '
      '${availableHeightMm.toStringAsFixed(1)} mm)';
}

abstract interface class TextMetrics {
  TextExtent measure(TextElement element, PrintSpec spec);
}

final class HeuristicTextMetrics implements TextMetrics {
  const HeuristicTextMetrics({
    this.averageGlyphWidthRatio = 0.55,
    this.lineHeightRatio = 1.25,
    this.slackMm = 0.5,
  });

  final double averageGlyphWidthRatio;

  final double lineHeightRatio;

  final double slackMm;

  @override
  TextExtent measure(TextElement element, PrintSpec spec) {
    final boxWidthMm = element.box.w * spec.effectiveSpreadWidthMm;
    final boxHeightMm = element.box.h * spec.effectiveSpreadHeightMm;
    final fontSizeMm = element.fontSizeNorm * spec.effectiveSpreadHeightMm;
    final text = element.text.trim();
    if (text.isEmpty || fontSizeMm <= 0 || boxWidthMm <= 0) {
      return TextExtent(
        lineCount: 0,
        requiredHeightMm: 0,
        availableHeightMm: boxHeightMm,
        exceedsBox: false,
      );
    }
    final glyphMm = math.max(fontSizeMm * averageGlyphWidthRatio, 0.01);
    final maxCharsPerLine = math.max(1, (boxWidthMm / glyphMm).floor());
    final lines = countLines(text, maxCharsPerLine);
    final required = lines * fontSizeMm * lineHeightRatio;
    return TextExtent(
      lineCount: lines,
      requiredHeightMm: required,
      availableHeightMm: boxHeightMm,
      exceedsBox: required > boxHeightMm + slackMm,
    );
  }

  static int countLines(String text, int maxCharsPerLine) {
    const separator = 1;
    var lines = 1;
    var used = 0;
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      if (used == 0) {
        if (word.length <= maxCharsPerLine) {
          used = word.length;
        } else {
          final extra = (word.length - 1) ~/ maxCharsPerLine;
          lines += extra;
          used = word.length - extra * maxCharsPerLine;
        }
        continue;
      }
      if (used + separator + word.length <= maxCharsPerLine) {
        used += separator + word.length;
        continue;
      }
      lines++;
      if (word.length <= maxCharsPerLine) {
        used = word.length;
      } else {
        final extra = (word.length - 1) ~/ maxCharsPerLine;
        lines += extra;
        used = word.length - extra * maxCharsPerLine;
      }
    }
    return lines;
  }
}

abstract interface class FaceEdgeDetector {
  List<NormalizedRect> faces(PhotoAssetRef asset, DesignDocument document);
}

class PhotoAssetRef {
  const PhotoAssetRef({required this.id, required this.sha256});

  final String id;

  final String sha256;

  @override
  String toString() => 'PhotoAssetRef($id)';
}
