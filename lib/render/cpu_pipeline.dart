import 'dart:math' as math;
import 'dart:typed_data';

import 'package:design_core/design_core.dart';

enum CpuColorSpace {
  encoded,

  linear,
}

final class SrgbLuts {
  SrgbLuts._(this.decode, this.encode);

  static final SrgbLuts standard = _build();

  final Float32List decode;

  final Uint8List encode;

  double toLinear(int byte) => decode[byte.clamp(0, 255)];

  int toSrgbByte(num linear) {
    final value = linear.isFinite ? linear.clamp(0.0, 1.0) : 0.0;
    return encode[(value * 4095).round()];
  }

  static SrgbLuts _build() {
    final decode = Float32List(256);
    for (var i = 0; i < 256; i++) {
      final v = i / 255;
      decode[i] = v <= 0.04045 ? v / 12.92 : _pow((v + 0.055) / 1.055, 2.4);
    }
    final encode = Uint8List(4096);
    for (var i = 0; i < 4096; i++) {
      final v = i / 4095;
      final srgb = v <= 0.0031308
          ? v * 12.92
          : 1.055 * _pow(v, 1 / 2.4) - 0.055;
      encode[i] = (srgb * 255).round().clamp(0, 255);
    }
    return SrgbLuts._(decode, encode);
  }

  static double _pow(double base, double exponent) =>
      math.pow(base, exponent).toDouble();
}

abstract final class CpuPipeline {
  static Uint8List applyMatrix({
    required Uint8List rgba,
    required List<double> matrix,
    CpuColorSpace space = CpuColorSpace.encoded,
    SrgbLuts? luts,
  }) {
    if (matrix.length != 20) {
      throw ArgumentError.value(
        matrix.length,
        'matrix',
        'a 4x5 colour matrix has 20 entries',
      );
    }
    if (rgba.length % 4 != 0) {
      throw ArgumentError.value(rgba.length, 'rgba', 'must be RGBA bytes');
    }
    final output = Uint8List(rgba.length);
    if (AdjustmentMatrix.isIdentity(matrix)) {
      output.setAll(0, rgba);
      return output;
    }
    final table = space == CpuColorSpace.linear
        ? (luts ?? SrgbLuts.standard)
        : null;
    final m0 = matrix[0], m1 = matrix[1], m2 = matrix[2], o0 = matrix[4];
    final m3 = matrix[5], m4 = matrix[6], m5 = matrix[7], o1 = matrix[9];
    final m6 = matrix[10], m7 = matrix[11], m8 = matrix[12], o2 = matrix[14];

    for (var i = 0; i < rgba.length; i += 4) {
      final double r;
      final double g;
      final double b;
      if (table == null) {
        r = rgba[i].toDouble();
        g = rgba[i + 1].toDouble();
        b = rgba[i + 2].toDouble();
      } else {
        r = table.decode[rgba[i]];
        g = table.decode[rgba[i + 1]];
        b = table.decode[rgba[i + 2]];
      }
      final nr = m0 * r + m1 * g + m2 * b + o0;
      final ng = m3 * r + m4 * g + m5 * b + o1;
      final nb = m6 * r + m7 * g + m8 * b + o2;
      if (table == null) {
        output[i] = _byte(nr);
        output[i + 1] = _byte(ng);
        output[i + 2] = _byte(nb);
      } else {
        output[i] = table.toSrgbByte(nr);
        output[i + 1] = table.toSrgbByte(ng);
        output[i + 2] = table.toSrgbByte(nb);
      }
      output[i + 3] = rgba[i + 3];
    }
    return output;
  }

  static Uint8List applyAdjustment({
    required Uint8List rgba,
    required PhotoAdjustment adjustment,
    CpuColorSpace space = CpuColorSpace.encoded,
    SrgbLuts? luts,
  }) => applyMatrix(
    rgba: rgba,
    matrix: space == CpuColorSpace.linear
        ? AdjustmentMatrix.linear(adjustment)
        : AdjustmentMatrix.encoded(adjustment),
    space: space,
    luts: luts,
  );

  static int _byte(double value) {
    if (value.isNaN) return 0;
    return value.round().clamp(0, 255);
  }
}
