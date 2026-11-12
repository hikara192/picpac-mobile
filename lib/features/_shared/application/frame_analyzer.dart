import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_core/design_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class FrameAnalyzer {
  Future<FrameStats?> analyze(String filePath);
}

final class IsolateFrameAnalyzer implements FrameAnalyzer {
  const IsolateFrameAnalyzer();

  static const int proxySide = 512;

  @override
  Future<FrameStats?> analyze(String filePath) async {
    final proxy = await decodeFrameProxy(filePath, proxySide);
    if (proxy == null) return null;
    final rgba = proxy.rgba;
    final width = proxy.width;
    final height = proxy.height;
    try {
      return await Isolate.run(
        () => computeFrameStats(rgba, width: width, height: height),
      );
    } on Object {
      return computeFrameStats(rgba, width: width, height: height);
    }
  }
}

final Provider<FrameAnalyzer> frameAnalyzerProvider = Provider<FrameAnalyzer>(
  (ref) => const IsolateFrameAnalyzer(),
);

Future<FrameStats?> analyzeFileProxy(String path, int side) async {
  final proxy = await decodeFrameProxy(path, side);
  if (proxy == null) return null;
  return computeFrameStats(
    proxy.rgba,
    width: proxy.width,
    height: proxy.height,
  );
}

Future<({Uint8List rgba, int width, int height})?> decodeFrameProxy(
  String path,
  int side,
) async {
  ui.Codec? codec;
  ui.Image? image;
  try {
    final file = File(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: side,
      allowUpscaling: false,
    );
    final frame = await codec.getNextFrame();
    image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    return (
      rgba: data.buffer.asUint8List(),
      width: image.width,
      height: image.height,
    );
  } on Object {
    return null;
  } finally {
    image?.dispose();
    codec?.dispose();
  }
}

FrameStats computeFrameStats(
  Uint8List rgba, {
  required int width,
  required int height,
}) {
  final histogram = List<int>.filled(256, 0);
  var weightSum = 0.0;
  var meanR = 0.0;
  var meanG = 0.0;
  var meanB = 0.0;
  var chromaSum = 0.0;
  var highlights = 0;
  var count = 0;

  for (var index = 0; index + 3 < rgba.length; index += 4) {
    if (count >= width * height) break;
    if (rgba[index + 3] < 8) continue;
    final r = rgba[index] / 255;
    final g = rgba[index + 1] / 255;
    final b = rgba[index + 2] / 255;
    final luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    histogram[(luma * 255).round().clamp(0, 255)]++;
    count++;
    if (luma > 0.98) highlights++;

    final maxChannel = math.max(r, math.max(g, b));
    final minChannel = math.min(r, math.min(g, b));
    final chroma = maxChannel <= 0
        ? 0.0
        : (maxChannel - minChannel) / maxChannel;
    chromaSum += chroma;

    if (luma <= 0.01 || luma >= 0.92) continue;
    final weight = (1 - chroma) * (1 - chroma);
    meanR += r * weight;
    meanG += g * weight;
    meanB += b * weight;
    weightSum += weight;
  }

  if (count == 0) {
    return FrameStats(
      lumaHistogram: histogram,
      meanR: 0.5,
      meanG: 0.5,
      meanB: 0.5,
      meanChroma: 0,
      sampleCount: 0,
    );
  }

  return FrameStats(
    lumaHistogram: histogram,
    meanR: weightSum > 0 ? meanR / weightSum : 0.5,
    meanG: weightSum > 0 ? meanG / weightSum : 0.5,
    meanB: weightSum > 0 ? meanB / weightSum : 0.5,
    meanChroma: chromaSum / count,
    highlightFraction: highlights / count,
    sampleCount: count,
  );
}
