import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../core/json_read.dart';
import '../document/adjustment_limits.dart';
import '../document/design_format_exception.dart';

export 'adjustment_limits.dart'
    show AdjustmentLimit, AdjustmentLimits, PhotoAdjustmentField;

@immutable
final class LookSetting {
  const LookSetting({required this.id, required this.strength});

  final String id;

  final double strength;

  bool get isNeutral => strength <= 0;

  LookSetting copyWith({String? id, double? strength}) => LookSetting(
    id: id ?? this.id,
    strength: AdjustmentLimits.clampStrength(strength ?? this.strength),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'strength': strength,
  };

  factory LookSetting.fromJson(Object? json, String path) {
    final map = JsonRead.object(json, path);
    final strength = JsonRead.number(map['strength'], '$path.strength');
    if (strength < 0 || strength > 1) {
      throw DesignFormatException(
        code: DesignFormatErrorCode.outOfRange,
        message: 'look strength must be within 0..1, got $strength',
        path: '$path.strength',
      );
    }
    return LookSetting(
      id: JsonRead.id(map['id'], '$path.id'),
      strength: strength,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LookSetting && other.id == id && other.strength == strength;

  @override
  int get hashCode => Object.hash(id, strength);

  @override
  String toString() => 'LookSetting($id @ $strength)';
}

@immutable
final class PhotoAdjustment {
  const PhotoAdjustment({
    this.exposure = 0,
    this.contrast = 0,
    this.temperature = 0,
    this.tint = 0,
    this.saturation = 0,
    this.vibrance = 0,
    this.look,
  });

  static const PhotoAdjustment neutral = PhotoAdjustment();

  final double exposure;

  final double contrast;

  final double temperature;

  final double tint;

  final double saturation;

  final double vibrance;

  final LookSetting? look;

  bool get isNeutral =>
      exposure == 0 &&
      contrast == 0 &&
      temperature == 0 &&
      tint == 0 &&
      saturation == 0 &&
      vibrance == 0 &&
      (look == null || look!.isNeutral);

  double valueOf(PhotoAdjustmentField field) => switch (field) {
    PhotoAdjustmentField.exposure => exposure,
    PhotoAdjustmentField.contrast => contrast,
    PhotoAdjustmentField.temperature => temperature,
    PhotoAdjustmentField.tint => tint,
    PhotoAdjustmentField.saturation => saturation,
    PhotoAdjustmentField.vibrance => vibrance,
  };

  PhotoAdjustment withField(PhotoAdjustmentField field, double value) {
    final clamped = field.clamp(value);
    return switch (field) {
      PhotoAdjustmentField.exposure => copyWith(exposure: clamped),
      PhotoAdjustmentField.contrast => copyWith(contrast: clamped),
      PhotoAdjustmentField.temperature => copyWith(temperature: clamped),
      PhotoAdjustmentField.tint => copyWith(tint: clamped),
      PhotoAdjustmentField.saturation => copyWith(saturation: clamped),
      PhotoAdjustmentField.vibrance => copyWith(vibrance: clamped),
    };
  }

  PhotoAdjustment copyWith({
    double? exposure,
    double? contrast,
    double? temperature,
    double? tint,
    double? saturation,
    double? vibrance,
    LookSetting? look,
  }) => PhotoAdjustment(
    exposure: exposure ?? this.exposure,
    contrast: contrast ?? this.contrast,
    temperature: temperature ?? this.temperature,
    tint: tint ?? this.tint,
    saturation: saturation ?? this.saturation,
    vibrance: vibrance ?? this.vibrance,
    look: look ?? this.look,
  );

  PhotoAdjustment withLook(LookSetting? look) => PhotoAdjustment(
    exposure: exposure,
    contrast: contrast,
    temperature: temperature,
    tint: tint,
    saturation: saturation,
    vibrance: vibrance,
    look: look,
  );

  PhotoAdjustment clamped() => PhotoAdjustment(
    exposure: AdjustmentLimits.exposure.clamp(exposure),
    contrast: AdjustmentLimits.contrast.clamp(contrast),
    temperature: AdjustmentLimits.temperature.clamp(temperature),
    tint: AdjustmentLimits.tint.clamp(tint),
    saturation: AdjustmentLimits.saturation.clamp(saturation),
    vibrance: AdjustmentLimits.vibrance.clamp(vibrance),
    look: look,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'exposure': exposure,
    'contrast': contrast,
    'temperature': temperature,
    'tint': tint,
    'saturation': saturation,
    'vibrance': vibrance,
    if (look != null) 'look': look!.toJson(),
  };

  factory PhotoAdjustment.fromJson(Object? json, String path) {
    final map = JsonRead.object(json, path);
    double read(PhotoAdjustmentField field) {
      final value = JsonRead.optNumber(map[field.wire], '$path.${field.wire}');
      if (value == null) return 0;
      if (value < field.min || value > field.max) {
        throw DesignFormatException(
          code: DesignFormatErrorCode.outOfRange,
          message:
              '${field.wire} must be within ${field.min}..${field.max}, '
              'got $value',
          path: '$path.${field.wire}',
        );
      }
      return value;
    }

    final lookJson = map['look'];
    return PhotoAdjustment(
      exposure: read(PhotoAdjustmentField.exposure),
      contrast: read(PhotoAdjustmentField.contrast),
      temperature: read(PhotoAdjustmentField.temperature),
      tint: read(PhotoAdjustmentField.tint),
      saturation: read(PhotoAdjustmentField.saturation),
      vibrance: read(PhotoAdjustmentField.vibrance),
      look: lookJson == null
          ? null
          : LookSetting.fromJson(lookJson, '$path.look'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PhotoAdjustment &&
      other.exposure == exposure &&
      other.contrast == contrast &&
      other.temperature == temperature &&
      other.tint == tint &&
      other.saturation == saturation &&
      other.vibrance == vibrance &&
      other.look == look;

  @override
  int get hashCode => Object.hash(
    exposure,
    contrast,
    temperature,
    tint,
    saturation,
    vibrance,
    look,
  );

  @override
  String toString() =>
      'PhotoAdjustment(exposure: $exposure, contrast: $contrast, '
      'temperature: $temperature, tint: $tint, saturation: $saturation, '
      'vibrance: $vibrance, look: $look)';

  double get magnitude => math.max(
    math.max(exposure.abs(), contrast.abs() / 100),
    math.max(
      math.max(temperature.abs(), tint.abs()) / 100,
      math.max(saturation.abs(), vibrance.abs()) / 100,
    ),
  );
}
