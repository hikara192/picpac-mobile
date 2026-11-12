import 'package:meta/meta.dart';

import '../document/photo_adjustment.dart';

@immutable
final class LookPreset {
  const LookPreset({
    required this.id,
    required this.nameKey,
    this.exposure = 0,
    this.contrast = 0,
    this.temperature = 0,
    this.tint = 0,
    this.saturation = 0,
    this.vibrance = 0,
    this.channelMix,
  });

  final String id;

  final String nameKey;

  final double exposure;

  final double contrast;

  final double temperature;

  final double tint;

  final double saturation;

  final double vibrance;

  final List<double>? channelMix;

  bool get isNeutral =>
      exposure == 0 &&
      contrast == 0 &&
      temperature == 0 &&
      tint == 0 &&
      saturation == 0 &&
      vibrance == 0 &&
      channelMix == null;

  PhotoAdjustment asAdjustment(double strength) {
    final s = AdjustmentLimits.clampStrength(strength);
    if (s <= 0) return PhotoAdjustment.neutral;
    return PhotoAdjustment(
      exposure: exposure * s,
      contrast: contrast * s,
      temperature: temperature * s,
      tint: tint * s,
      saturation: saturation * s,
      vibrance: vibrance * s,
    ).clamped();
  }

  List<double>? channelMixAt(double strength) {
    final mix = channelMix;
    if (mix == null) return null;
    final s = AdjustmentLimits.clampStrength(strength);
    if (s <= 0) return null;
    return <double>[
      for (var i = 0; i < 9; i++)
        _identityMix[i] + (mix[i] - _identityMix[i]) * s,
    ];
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'nameKey': nameKey,
    'exposure': exposure,
    'contrast': contrast,
    'temperature': temperature,
    'tint': tint,
    'saturation': saturation,
    'vibrance': vibrance,
    if (channelMix != null) 'channelMix': channelMix,
  };

  @override
  String toString() => 'LookPreset($id @ v${LookLibrary.version})';
}

@immutable
final class ResolvedAdjustment {
  const ResolvedAdjustment({
    this.exposure = 0,
    this.contrast = 0,
    this.temperature = 0,
    this.tint = 0,
    this.saturation = 0,
    this.vibrance = 0,
    this.channelMix,
  });

  static const ResolvedAdjustment neutral = ResolvedAdjustment();

  final double exposure;

  final double contrast;

  final double temperature;

  final double tint;

  final double saturation;

  final double vibrance;

  final List<double>? channelMix;

  bool get isNeutral =>
      exposure == 0 &&
      contrast == 0 &&
      temperature == 0 &&
      tint == 0 &&
      saturation == 0 &&
      channelMix == null;

  PhotoAdjustment toPhotoAdjustment() => PhotoAdjustment(
    exposure: exposure,
    contrast: contrast,
    temperature: temperature,
    tint: tint,
    saturation: saturation,
    vibrance: vibrance,
  ).clamped();

  @override
  String toString() =>
      'ResolvedAdjustment(ev: $exposure, contrast: $contrast, '
      'temp: $temperature, tint: $tint, sat: $saturation, '
      'vibrance: $vibrance, mix: ${channelMix != null})';
}

abstract final class LookLibrary {
  static const int version = 1;

  static const String neutralId = 'as_is';

  static const LookPreset asIs = LookPreset(id: neutralId, nameKey: 'lookAsIs');

  static const LookPreset warm = LookPreset(
    id: 'warm',
    nameKey: 'lookWarm',
    exposure: 0.05,
    contrast: 4,
    temperature: 16,
    tint: 3,
    saturation: 5,
  );

  static const LookPreset film = LookPreset(
    id: 'film',
    nameKey: 'lookFilm',
    exposure: 0.02,
    contrast: 12,
    temperature: 5,
    tint: -3,
    saturation: -8,
    channelMix: <double>[
      1.03, 0.00, -0.01, //
      0.00, 1.00, 0.00, //
      -0.01, 0.02, 0.96, //
    ],
  );

  static const LookPreset bright = LookPreset(
    id: 'bright',
    nameKey: 'lookBright',
    exposure: 0.28,
    contrast: 10,
    temperature: 2,
    saturation: 4,
  );

  static const LookPreset soft = LookPreset(
    id: 'soft',
    nameKey: 'lookSoft',
    exposure: 0.10,
    contrast: -12,
    temperature: 3,
    saturation: -5,
  );

  static const LookPreset mono = LookPreset(
    id: 'mono',
    nameKey: 'lookMono',
    exposure: 0.03,
    contrast: 12,
    saturation: -100,
  );

  static const List<LookPreset> presets = <LookPreset>[
    asIs,
    warm,
    film,
    bright,
    soft,
    mono,
  ];

  static LookPreset? byId(String? id) {
    if (id == null) return null;
    for (final preset in presets) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  static bool containsId(String? id) => byId(id) != null;

  static List<String> get ids => <String>[
    for (final preset in presets) preset.id,
  ];

  static ResolvedAdjustment resolve(PhotoAdjustment adjustment) {
    final preset = byId(adjustment.look?.id);
    final strength = adjustment.look?.strength ?? 0;
    if (preset == null || strength <= 0) {
      return ResolvedAdjustment(
        exposure: adjustment.exposure,
        contrast: adjustment.contrast,
        temperature: adjustment.temperature,
        tint: adjustment.tint,
        saturation: adjustment.saturation,
        vibrance: adjustment.vibrance,
      );
    }
    final delta = preset.asAdjustment(strength);
    final resolved = PhotoAdjustment(
      exposure: adjustment.exposure + delta.exposure,
      contrast: adjustment.contrast + delta.contrast,
      temperature: adjustment.temperature + delta.temperature,
      tint: adjustment.tint + delta.tint,
      saturation: adjustment.saturation + delta.saturation,
      vibrance: adjustment.vibrance + delta.vibrance,
    ).clamped();
    return ResolvedAdjustment(
      exposure: resolved.exposure,
      contrast: resolved.contrast,
      temperature: resolved.temperature,
      tint: resolved.tint,
      saturation: resolved.saturation,
      vibrance: resolved.vibrance,
      channelMix: preset.channelMixAt(strength),
    );
  }
}

const List<double> _identityMix = <double>[1, 0, 0, 0, 1, 0, 0, 0, 1];
