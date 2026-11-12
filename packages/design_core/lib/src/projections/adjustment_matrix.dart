import 'dart:math' as math;

import '../document/look_library.dart';
import '../document/photo_adjustment.dart';

abstract final class AdjustmentMatrix {
  static const List<double> identity = <double>[
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  static const List<double> lumaWeights = <double>[0.2126, 0.7152, 0.0722];

  static List<double> encoded(PhotoAdjustment adjustment) =>
      encodedFor(LookLibrary.resolve(adjustment));

  static List<double> encodedFor(ResolvedAdjustment adjustment) {
    if (adjustment.isNeutral) return identity;
    final scaled = _Scaled(encoded: true, adjustment: adjustment);
    return _compose(<List<double>>[
      scaled.whiteBalance(),
      scaled.exposure(),
      scaled.contrast(),
      scaled.saturation(),
      scaled.channelMix(),
    ]);
  }

  static List<double> linear(PhotoAdjustment adjustment) =>
      linearFor(LookLibrary.resolve(adjustment));

  static List<double> linearFor(ResolvedAdjustment adjustment) {
    if (adjustment.isNeutral) return identity;
    final scaled = _Scaled(encoded: false, adjustment: adjustment);
    return _compose(<List<double>>[
      scaled.whiteBalance(),
      scaled.exposure(),
      scaled.contrast(),
      scaled.saturation(),
      scaled.channelMix(),
    ]);
  }

  static bool isIdentity(List<double> matrix, [double epsilon = 1e-9]) {
    if (matrix.length != 20) return false;
    for (var i = 0; i < 20; i++) {
      if ((matrix[i] - identity[i]).abs() > epsilon) return false;
    }
    return true;
  }

  static List<double> multiply(List<double> after, List<double> before) {
    final out = List<double>.filled(20, 0);
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 4; col++) {
        var sum = 0.0;
        for (var k = 0; k < 3; k++) {
          sum += after[row * 5 + k] * before[k * 5 + col];
        }
        out[row * 5 + col] = sum;
      }
      var offset = after[row * 5 + 4];
      for (var k = 0; k < 3; k++) {
        offset += after[row * 5 + k] * before[k * 5 + 4];
      }
      out[row * 5 + 4] = offset;
    }
    out[18] = 1;
    return out;
  }

  static List<double> _compose(List<List<double>> matrices) {
    var result = identity;
    for (final matrix in matrices) {
      result = multiply(matrix, result);
    }
    return result;
  }
}

final class _Scaled {
  _Scaled({required this.encoded, required this.adjustment});

  final bool encoded;
  final ResolvedAdjustment adjustment;

  double get _offsetScale => encoded ? 255 : 1;

  double get _contrastPivot => encoded ? 0.5 : 0.18;

  List<double> whiteBalance() {
    final t = adjustment.temperature;
    final tint = adjustment.tint;
    if (t == 0 && tint == 0) return AdjustmentMatrix.identity;
    final kR = 1 + 0.0009 * t;
    final kG = 1 - 0.0007 * tint;
    final kB = 1 - 0.0011 * t;
    return <double>[
      kR, 0, 0, 0, 0, //
      0, kG, 0, 0, 0, //
      0, 0, kB, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }

  List<double> exposure() {
    final ev = adjustment.exposure;
    if (ev == 0) return AdjustmentMatrix.identity;
    final gain = math.pow(2, ev).toDouble();
    return <double>[
      gain, 0, 0, 0, 0, //
      0, gain, 0, 0, 0, //
      0, 0, gain, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }

  List<double> contrast() {
    final value = adjustment.contrast;
    if (value == 0) return AdjustmentMatrix.identity;
    final k = 1 + value / 100 * 0.5;
    final offset = _contrastPivot * _offsetScale * (1 - k);
    return <double>[
      k, 0, 0, 0, offset, //
      0, k, 0, 0, offset, //
      0, 0, k, 0, offset, //
      0, 0, 0, 1, 0, //
    ];
  }

  List<double> saturation() {
    final value = adjustment.saturation;
    if (value == 0) return AdjustmentMatrix.identity;
    final s = 1 + value / 100;
    final lr = AdjustmentMatrix.lumaWeights[0];
    final lg = AdjustmentMatrix.lumaWeights[1];
    final lb = AdjustmentMatrix.lumaWeights[2];
    return <double>[
      lr + s * (1 - lr), lg * (1 - s), lb * (1 - s), 0, 0, //
      lr * (1 - s), lg + s * (1 - lg), lb * (1 - s), 0, 0, //
      lr * (1 - s), lg * (1 - s), lb + s * (1 - lb), 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }

  List<double> channelMix() {
    final mix = adjustment.channelMix;
    if (mix == null) return AdjustmentMatrix.identity;
    return <double>[
      mix[0], mix[1], mix[2], 0, 0, //
      mix[3], mix[4], mix[5], 0, 0, //
      mix[6], mix[7], mix[8], 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }
}
