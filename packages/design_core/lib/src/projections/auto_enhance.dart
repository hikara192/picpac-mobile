import 'dart:math' as math;

import '../analysis/frame_stats.dart';
import '../document/look_library.dart';
import '../document/photo_adjustment.dart';

abstract final class AutoEnhance {
  static const double _targetLumaLinear = 0.18;

  static const double _deadZoneStops = 0.5;

  static const double _evCompression = 0.6;

  static const double _minEv = -1;
  static const double _maxEv = 1;

  static const double _minContrast = -20;
  static const double _maxContrast = 35;

  static const double _maxContrastWithHighlights = 8;

  static const double _highlightEvGuard = 0.02;

  static const double _highlightContrastGuard = 0.05;

  static const double _maxTemperature = 20;

  static const double _maxTint = 15;

  static const double _greyChroma = 0.12;

  static const double _saturationLift = 10;

  static const double _minChannelMean = 0.02;

  static const double _maxChannelMean = 0.98;

  static const double _wbDeadZone = 0.03;

  static const double _temperatureSlope = -500;

  static const double _tintSlope = 300;

  static PhotoAdjustment propose(
    PhotoAnalysis analysis, {
    String? lookId,
    double lookStrength = 1,
  }) {
    if (analysis.pixelCount == 0) {
      return PhotoAdjustment.neutral;
    }

    final exposure = _proposeExposure(analysis);
    final contrast = _proposeContrast(analysis);
    final warmth = _proposeTemperature(analysis);
    final tint = _proposeTint(analysis);
    final saturation = analysis.chromaMean < _greyChroma
        ? _saturationLift
        : 0.0;

    final look =
        LookLibrary.byId(lookId)?.asAdjustment(lookStrength) ??
        PhotoAdjustment.neutral;

    return PhotoAdjustment(
      exposure: _round(exposure - look.exposure, 2),
      contrast: _round(contrast - look.contrast, 1),
      temperature: _round(warmth - look.temperature, 1),
      tint: _round(tint - look.tint, 1),
      saturation: _round(saturation - look.saturation, 1),
    ).clamped();
  }

  static double _proposeExposure(PhotoAnalysis analysis) {
    final linear = _srgbToLinear(analysis.lumaMean).clamp(1e-4, 1.0).toDouble();
    final stops = _log2(linear / _targetLumaLinear);
    final magnitude = (stops.abs() - _deadZoneStops).clamp(0.0, 8.0).toDouble();
    var ev = -stops.sign * magnitude * _evCompression;
    if (analysis.highlightFraction > _highlightEvGuard && ev > 0) ev = 0;
    return ev.clamp(_minEv, _maxEv).toDouble();
  }

  static double _proposeContrast(PhotoAnalysis analysis) {
    final span = (analysis.lumaP99 - analysis.lumaP1) * 255;
    if (span <= 1) return 0;
    final gain = (239 / span).clamp(0.85, 1.35).toDouble();
    var contrast = (gain - 1) * 200;
    final ceiling = analysis.highlightFraction > _highlightContrastGuard
        ? _maxContrastWithHighlights
        : _maxContrast;
    return contrast.clamp(_minContrast, ceiling).toDouble();
  }

  static double _proposeTemperature(PhotoAnalysis analysis) {
    if (!_wbTrusted(analysis)) return 0;
    final gainR = analysis.greyWorldGainR;
    final gainB = analysis.greyWorldGainB;
    if ((gainR - 1).abs() < _wbDeadZone && (gainB - 1).abs() < _wbDeadZone) {
      return 0;
    }
    final ratio = gainB / gainR;
    if (ratio <= 0) return 0;
    final value = _temperatureSlope * math.log(ratio);
    return value.clamp(-_maxTemperature, _maxTemperature).toDouble();
  }

  static double _proposeTint(PhotoAnalysis analysis) {
    if (!_wbTrusted(analysis)) return 0;
    final cast = analysis.greenCast;
    if ((cast - 1).abs() < _wbDeadZone) return 0;
    final value = _tintSlope * math.log(cast);
    return value.clamp(-_maxTint, _maxTint).toDouble();
  }

  static bool _wbTrusted(PhotoAnalysis analysis) {
    for (final mean in <double>[
      analysis.meanR,
      analysis.meanG,
      analysis.meanB,
    ]) {
      if (mean < _minChannelMean || mean > _maxChannelMean) return false;
    }
    return true;
  }

  static double _srgbToLinear(double value) {
    final v = value.clamp(0.0, 1.0).toDouble();
    return v <= 0.04045
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  static double _log2(double value) => math.log(value) / math.ln2;

  static double _round(double value, int decimals) {
    final factor = math.pow(10, decimals).toDouble();
    return (value * factor).roundToDouble() / factor;
  }
}
