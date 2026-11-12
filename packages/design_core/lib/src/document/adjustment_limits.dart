import 'package:meta/meta.dart';

enum PhotoAdjustmentField {
  exposure('exposure'),

  contrast('contrast'),

  temperature('temperature'),

  tint('tint'),

  saturation('saturation'),

  vibrance('vibrance');

  const PhotoAdjustmentField(this.wire);

  final String wire;

  AdjustmentLimit get limit => AdjustmentLimits.of(this);

  double get min => limit.min;

  double get max => limit.max;

  double clamp(double value) => limit.clamp(value);

  static PhotoAdjustmentField? tryParse(String? raw) {
    if (raw == null) return null;
    for (final field in values) {
      if (field.wire == raw) return field;
    }
    return null;
  }
}

@immutable
final class AdjustmentLimit {
  const AdjustmentLimit({
    required this.id,
    required this.labelKey,
    required this.min,
    required this.max,
    required this.step,
    this.field,
    this.uiExposed = true,
    this.uiMin,
    this.uiMax,
    this.decimals = 2,
  });

  final String id;

  final String labelKey;

  final PhotoAdjustmentField? field;

  final double min;

  final double max;

  final double step;

  final bool uiExposed;

  final double? uiMin;

  final double? uiMax;

  final int decimals;

  double get uiLower => uiMin ?? min;

  double get uiUpper => uiMax ?? max;

  bool get isNeutralOnly => min == 0 && max == 0;

  double clamp(double value) {
    if (value.isNaN) return min <= 0 && max >= 0 ? 0 : min;
    if (value == double.infinity) return max;
    if (value == double.negativeInfinity) return min;
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  double uiClamp(double value) =>
      clamp(value).clamp(uiLower, uiUpper).toDouble();

  double snap(double value) {
    final clamped = clamp(value);
    if (step <= 0) return clamped;
    final steps = (clamped / step).round();
    return clamp(steps * step);
  }

  @override
  String toString() =>
      'AdjustmentLimit($id, $min..$max, step $step, ui $uiLower..$uiUpper)';
}

abstract final class AdjustmentLimits {
  static const AdjustmentLimit exposure = AdjustmentLimit(
    id: 'exposure',
    field: PhotoAdjustmentField.exposure,
    labelKey: 'editorToolLight',
    min: -2,
    max: 2,
    step: 0.05,
    uiMin: -1,
    uiMax: 1,
    decimals: 2,
  );

  static const AdjustmentLimit contrast = AdjustmentLimit(
    id: 'contrast',
    field: PhotoAdjustmentField.contrast,
    labelKey: 'editorAdjustContrast',
    min: -100,
    max: 100,
    step: 1,
    uiMin: -40,
    uiMax: 40,
    decimals: 0,
  );

  static const AdjustmentLimit temperature = AdjustmentLimit(
    id: 'temperature',
    field: PhotoAdjustmentField.temperature,
    labelKey: 'editorToolWarmth',
    min: -100,
    max: 100,
    step: 1,
    uiMin: -50,
    uiMax: 50,
    decimals: 0,
  );

  static const AdjustmentLimit tint = AdjustmentLimit(
    id: 'tint',
    field: PhotoAdjustmentField.tint,
    labelKey: 'editorAdjustTint',
    min: -100,
    max: 100,
    step: 1,
    uiExposed: false,
    decimals: 0,
  );

  static const AdjustmentLimit saturation = AdjustmentLimit(
    id: 'saturation',
    field: PhotoAdjustmentField.saturation,
    labelKey: 'editorAdjustSaturation',
    min: -100,
    max: 100,
    step: 1,
    uiMin: -30,
    uiMax: 25,
    decimals: 0,
  );

  static const AdjustmentLimit vibrance = AdjustmentLimit(
    id: 'vibrance',
    field: PhotoAdjustmentField.vibrance,
    labelKey: 'editorAdjustVibrance',
    min: -100,
    max: 100,
    step: 1,
    uiExposed: false,
    decimals: 0,
  );

  static const AdjustmentLimit lookStrength = AdjustmentLimit(
    id: 'lookStrength',
    labelKey: 'editorStyleStrength',
    min: 0,
    max: 1,
    step: 0.05,
    decimals: 2,
  );

  static const List<AdjustmentLimit> scalars = <AdjustmentLimit>[
    exposure,
    contrast,
    temperature,
    tint,
    saturation,
    vibrance,
  ];

  static const List<AdjustmentLimit> all = <AdjustmentLimit>[
    ...scalars,
    lookStrength,
  ];

  static AdjustmentLimit of(PhotoAdjustmentField field) => switch (field) {
    PhotoAdjustmentField.exposure => exposure,
    PhotoAdjustmentField.contrast => contrast,
    PhotoAdjustmentField.temperature => temperature,
    PhotoAdjustmentField.tint => tint,
    PhotoAdjustmentField.saturation => saturation,
    PhotoAdjustmentField.vibrance => vibrance,
  };

  static AdjustmentLimit? tryById(String id) {
    for (final limit in all) {
      if (limit.id == id) return limit;
    }
    return null;
  }

  static double clampOf(PhotoAdjustmentField field, double value) =>
      of(field).clamp(value);

  static double clampStrength(double value) => lookStrength.clamp(value);
}
