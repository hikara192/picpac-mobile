import 'package:meta/meta.dart';

import '../core/json_read.dart';
import '../document/design_format_exception.dart';

const double kUnitEpsilon = 1e-6;

enum QuarterTurn {
  none(0),

  cw90(90),

  cw180(180),

  cw270(270);

  const QuarterTurn(this.degrees);

  final int degrees;

  bool get swapsAxes => degrees == 90 || degrees == 270;

  bool get isNone => this == QuarterTurn.none;

  QuarterTurn get next => switch (this) {
    QuarterTurn.none => QuarterTurn.cw90,
    QuarterTurn.cw90 => QuarterTurn.cw180,
    QuarterTurn.cw180 => QuarterTurn.cw270,
    QuarterTurn.cw270 => QuarterTurn.none,
  };

  QuarterTurn get previous => switch (this) {
    QuarterTurn.none => QuarterTurn.cw270,
    QuarterTurn.cw270 => QuarterTurn.cw180,
    QuarterTurn.cw180 => QuarterTurn.cw90,
    QuarterTurn.cw90 => QuarterTurn.none,
  };

  static QuarterTurn? tryParse(int degrees) {
    for (final turn in values) {
      if (turn.degrees == degrees) return turn;
    }
    return null;
  }

  static QuarterTurn fromDegrees(int degrees) => tryParse(degrees) ?? none;
}

@immutable
final class NormalizedPoint {
  const NormalizedPoint(this.x, this.y);

  static const NormalizedPoint center = NormalizedPoint(0.5, 0.5);

  static const NormalizedPoint origin = NormalizedPoint(0, 0);

  final double x;

  final double y;

  bool get isInsideUnitSquare =>
      x >= -kUnitEpsilon &&
      x <= 1 + kUnitEpsilon &&
      y >= -kUnitEpsilon &&
      y <= 1 + kUnitEpsilon;

  NormalizedPoint clamped() => NormalizedPoint(
    x.clamp(0.0, 1.0).toDouble(),
    y.clamp(0.0, 1.0).toDouble(),
  );

  NormalizedPoint copyWith({double? x, double? y}) =>
      NormalizedPoint(x ?? this.x, y ?? this.y);

  Map<String, Object?> toJson() => <String, Object?>{'x': x, 'y': y};

  factory NormalizedPoint.fromJson(Object? json, String path) {
    final map = JsonRead.object(json, path);
    return NormalizedPoint(
      JsonRead.number(map['x'], '$path.x'),
      JsonRead.number(map['y'], '$path.y'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NormalizedPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'NormalizedPoint($x, $y)';
}

@immutable
final class NormalizedRect {
  const NormalizedRect({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  static const NormalizedRect unit = NormalizedRect(x: 0, y: 0, w: 1, h: 1);

  final double x;

  final double y;

  final double w;

  final double h;

  double get right => x + w;

  double get bottom => y + h;

  double get area => w * h;

  double? get aspect => h == 0 ? null : w / h;

  bool get isValidUnitRect =>
      w > kUnitEpsilon &&
      h > kUnitEpsilon &&
      x >= -kUnitEpsilon &&
      y >= -kUnitEpsilon &&
      right <= 1 + kUnitEpsilon &&
      bottom <= 1 + kUnitEpsilon;

  bool containsPoint(NormalizedPoint point) =>
      point.x >= x - kUnitEpsilon &&
      point.x <= right + kUnitEpsilon &&
      point.y >= y - kUnitEpsilon &&
      point.y <= bottom + kUnitEpsilon;

  bool intersects(NormalizedRect other) {
    final dx =
        (right < other.right ? right : other.right) -
        (x > other.x ? x : other.x);
    final dy =
        (bottom < other.bottom ? bottom : other.bottom) -
        (y > other.y ? y : other.y);
    return dx > kUnitEpsilon && dy > kUnitEpsilon;
  }

  bool containsRect(NormalizedRect other) =>
      other.x >= x - kUnitEpsilon &&
      other.y >= y - kUnitEpsilon &&
      other.right <= right + kUnitEpsilon &&
      other.bottom <= bottom + kUnitEpsilon;

  NormalizedRect? intersection(NormalizedRect other) {
    final left = x > other.x ? x : other.x;
    final top = y > other.y ? y : other.y;
    final rightEdge = right < other.right ? right : other.right;
    final bottomEdge = bottom < other.bottom ? bottom : other.bottom;
    if (rightEdge - left <= kUnitEpsilon || bottomEdge - top <= kUnitEpsilon) {
      return null;
    }
    return NormalizedRect(
      x: left,
      y: top,
      w: rightEdge - left,
      h: bottomEdge - top,
    );
  }

  NormalizedRect deflate(double inset) => NormalizedRect(
    x: x + inset,
    y: y + inset,
    w: w - 2 * inset,
    h: h - 2 * inset,
  );

  NormalizedRect clamped() {
    final left = x.clamp(0.0, 1.0).toDouble();
    final top = y.clamp(0.0, 1.0).toDouble();
    final maxW = (1 - left).clamp(2 * kUnitEpsilon, 1.0).toDouble();
    final maxH = (1 - top).clamp(2 * kUnitEpsilon, 1.0).toDouble();
    return NormalizedRect(
      x: left,
      y: top,
      w: w.clamp(2 * kUnitEpsilon, maxW).toDouble(),
      h: h.clamp(2 * kUnitEpsilon, maxH).toDouble(),
    );
  }

  NormalizedRect copyWith({double? x, double? y, double? w, double? h}) =>
      NormalizedRect(
        x: x ?? this.x,
        y: y ?? this.y,
        w: w ?? this.w,
        h: h ?? this.h,
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'x': x,
    'y': y,
    'w': w,
    'h': h,
  };

  factory NormalizedRect.fromJson(Object? json, String path) {
    final map = JsonRead.object(json, path);
    final w = JsonRead.number(map['w'], '$path.w');
    final h = JsonRead.number(map['h'], '$path.h');
    if (w <= 0 || h <= 0) {
      throw DesignFormatException(
        code: DesignFormatErrorCode.outOfRange,
        message: 'rectangle size must be positive, got ${w}x$h',
        path: path,
      );
    }
    final rect = NormalizedRect(
      x: JsonRead.number(map['x'], '$path.x'),
      y: JsonRead.number(map['y'], '$path.y'),
      w: w,
      h: h,
    );
    if (!rect.isValidUnitRect) {
      throw DesignFormatException(
        code: DesignFormatErrorCode.outOfRange,
        message: 'rectangle must stay inside the 0..1 unit square',
        path: path,
        args: <String, Object?>{'x': rect.x, 'y': rect.y, 'w': w, 'h': h},
      );
    }
    return rect;
  }

  @override
  bool operator ==(Object other) =>
      other is NormalizedRect &&
      other.x == x &&
      other.y == y &&
      other.w == w &&
      other.h == h;

  @override
  int get hashCode => Object.hash(x, y, w, h);

  @override
  String toString() => 'NormalizedRect(x: $x, y: $y, w: $w, h: $h)';
}
