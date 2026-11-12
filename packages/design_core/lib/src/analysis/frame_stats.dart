import 'dart:math' as math;

import 'package:meta/meta.dart';

@immutable
final class FrameStats {
  const FrameStats({
    required this.lumaHistogram,
    required this.meanR,
    required this.meanG,
    required this.meanB,
    required this.meanChroma,
    this.highlightFraction = 0,
    this.sampleCount = 0,
    this.p1,
    this.p99,
  });

  final List<int> lumaHistogram;

  final double meanR;

  final double meanG;

  final double meanB;

  final double meanChroma;

  final double highlightFraction;

  final int sampleCount;

  final double? p1;

  final double? p99;

  bool get isUsable =>
      lumaHistogram.length == 256 &&
      lumaHistogram.every((count) => count >= 0) &&
      sampleCount >= 0;

  int get histogramTotal =>
      lumaHistogram.fold<int>(0, (sum, count) => sum + count);

  @override
  String toString() =>
      'FrameStats(rgb: ${meanR.toStringAsFixed(3)}/'
      '${meanG.toStringAsFixed(3)}/${meanB.toStringAsFixed(3)}, '
      'chroma: ${meanChroma.toStringAsFixed(3)}, '
      'highlights: ${highlightFraction.toStringAsFixed(3)})';
}

@immutable
final class PhotoAnalysis {
  const PhotoAnalysis({
    required this.lumaMean,
    required this.lumaP1,
    required this.lumaP99,
    required this.meanR,
    required this.meanG,
    required this.meanB,
    required this.chromaMean,
    required this.highlightFraction,
    required this.pixelCount,
  });

  static const double _fallbackP1 = 0;
  static const double _fallbackP99 = 1;

  final double lumaMean;

  final double lumaP1;

  final double lumaP99;

  final double meanR;

  final double meanG;

  final double meanB;

  final double chromaMean;

  final double highlightFraction;

  final int pixelCount;

  double get greyWorldGainR => meanR <= 0 ? 1 : meanG / meanR;

  double get greyWorldGainB => meanB <= 0 ? 1 : meanG / meanB;

  double get greenCast =>
      meanG <= 0 ? 1 : meanG / math.max(1e-6, (meanR + meanB) / 2);

  bool get isDark => lumaMean < 0.35;

  bool get isFlat => (lumaP99 - lumaP1) < 0.45;

  factory PhotoAnalysis.of(FrameStats stats) {
    final result = PhotoAnalysis.tryOf(stats);
    if (result == null) {
      throw ArgumentError.value(stats, 'stats', 'unusable frame statistics');
    }
    return result;
  }

  static PhotoAnalysis? tryOf(FrameStats stats) {
    if (!stats.isUsable) return null;
    final total = stats.histogramTotal;
    if (total <= 0) {
      return PhotoAnalysis(
        lumaMean: 0.5,
        lumaP1: _fallbackP1,
        lumaP99: _fallbackP99,
        meanR: 0.5,
        meanG: 0.5,
        meanB: 0.5,
        chromaMean: stats.meanChroma,
        highlightFraction: stats.highlightFraction,
        pixelCount: 0,
      );
    }
    var weighted = 0.0;
    for (var bin = 0; bin < stats.lumaHistogram.length; bin++) {
      weighted += bin * stats.lumaHistogram[bin];
    }
    final mean = (weighted / total) / 255;
    final p1 = stats.p1 ?? _percentile(stats.lumaHistogram, total, 0.01);
    final p99 = stats.p99 ?? _percentile(stats.lumaHistogram, total, 0.99);
    return PhotoAnalysis(
      lumaMean: _clamp01(mean),
      lumaP1: _clamp01(p1 / 255),
      lumaP99: _clamp01(p99 / 255),
      meanR: _clamp01(stats.meanR),
      meanG: _clamp01(stats.meanG),
      meanB: _clamp01(stats.meanB),
      chromaMean: _clamp01(stats.meanChroma),
      highlightFraction: _clamp01(stats.highlightFraction),
      pixelCount: stats.sampleCount > 0 ? stats.sampleCount : total,
    );
  }

  static double _percentile(List<int> histogram, int total, double fraction) {
    final target = (total * fraction).ceil();
    var cumulative = 0;
    for (var bin = 0; bin < histogram.length; bin++) {
      cumulative += histogram[bin];
      if (cumulative >= target) return bin.toDouble();
    }
    return histogram.length - 1;
  }

  static double _clamp01(double value) =>
      value.isFinite ? value.clamp(0.0, 1.0).toDouble() : 0;

  @override
  String toString() =>
      'PhotoAnalysis(luma: ${lumaMean.toStringAsFixed(3)}, '
      'p1: ${lumaP1.toStringAsFixed(3)}, '
      'p99: ${lumaP99.toStringAsFixed(3)}, '
      'rgb: ${meanR.toStringAsFixed(3)}/${meanG.toStringAsFixed(3)}/'
      '${meanB.toStringAsFixed(3)}, '
      'chroma: ${chromaMean.toStringAsFixed(3)})';
}
