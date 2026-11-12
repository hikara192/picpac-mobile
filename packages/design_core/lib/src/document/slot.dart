import 'package:meta/meta.dart';

import '../core/json_read.dart';
import '../document/design_format_exception.dart';
import 'geometry.dart';

const double kMinCropSize = 0.01;

@immutable
final class Crop {
  const Crop({this.x = 0, this.y = 0, this.w = 1, this.h = 1});

  static const Crop full = Crop();

  final double x;

  final double y;

  final double w;

  final double h;

  double get right => x + w;

  double get bottom => y + h;

  double get area => w * h;

  bool get isFull => x == 0 && y == 0 && w == 1 && h == 1;

  bool get isValid =>
      w > 0 &&
      h > 0 &&
      w <= 1 + kUnitEpsilon &&
      h <= 1 + kUnitEpsilon &&
      x >= -kUnitEpsilon &&
      y >= -kUnitEpsilon &&
      right <= 1 + kUnitEpsilon &&
      bottom <= 1 + kUnitEpsilon;

  Crop clamped() {
    final width = w.clamp(kMinCropSize, 1.0).toDouble();
    final height = h.clamp(kMinCropSize, 1.0).toDouble();
    final left = x.clamp(0.0, 1.0 - width).toDouble();
    final top = y.clamp(0.0, 1.0 - height).toDouble();
    return Crop(x: left, y: top, w: width, h: height);
  }

  Crop window({required double zoom, required NormalizedPoint anchor}) {
    final safeZoom = zoom < 1 ? 1.0 : zoom;
    final width = w / safeZoom;
    final height = h / safeZoom;
    final left = x + (w - width) * anchor.x.clamp(0.0, 1.0);
    final top = y + (h - height) * anchor.y.clamp(0.0, 1.0);
    return Crop(x: left, y: top, w: width, h: height);
  }

  Crop copyWith({double? x, double? y, double? w, double? h}) =>
      Crop(x: x ?? this.x, y: y ?? this.y, w: w ?? this.w, h: h ?? this.h);

  Map<String, Object?> toJson() => <String, Object?>{
    'x': x,
    'y': y,
    'w': w,
    'h': h,
  };

  factory Crop.fromJson(Object? json, String path) {
    final map = JsonRead.object(json, path);
    final crop = Crop(
      x: JsonRead.number(map['x'], '$path.x'),
      y: JsonRead.number(map['y'], '$path.y'),
      w: JsonRead.number(map['w'], '$path.w'),
      h: JsonRead.number(map['h'], '$path.h'),
    );
    if (!crop.isValid) {
      throw DesignFormatException(
        code: DesignFormatErrorCode.outOfRange,
        message: 'crop must be a positive window inside the 0..1 photo',
        path: path,
        args: <String, Object?>{
          'x': crop.x,
          'y': crop.y,
          'w': crop.w,
          'h': crop.h,
        },
      );
    }
    return crop;
  }

  @override
  bool operator ==(Object other) =>
      other is Crop &&
      other.x == x &&
      other.y == y &&
      other.w == w &&
      other.h == h;

  @override
  int get hashCode => Object.hash(x, y, w, h);

  @override
  String toString() => 'Crop(x: $x, y: $y, w: $w, h: $h)';
}

@immutable
final class Slot {
  const Slot({
    required this.id,
    this.photoId,
    this.crop = Crop.full,
    this.zoom = minZoom,
    this.anchor = NormalizedPoint.center,
    this.rotation = QuarterTurn.none,
    this.flipH = false,
  });

  static const double minZoom = 1;

  static const double maxZoom = 8;

  final String id;

  final String? photoId;

  final Crop crop;

  final double zoom;

  final NormalizedPoint anchor;

  final QuarterTurn rotation;

  final bool flipH;

  bool get isEmpty => photoId == null;

  bool get isFilled => photoId != null;

  bool get hasOrientation => !rotation.isNone || flipH;

  String get orientationKey => '${rotation.degrees}:${flipH ? 'h' : '-'}';

  Crop get effectiveSourceWindow => crop.window(zoom: zoom, anchor: anchor);

  Slot withFramingOf(Slot other) => Slot(
    id: id,
    photoId: other.photoId,
    crop: other.crop,
    zoom: other.zoom,
    anchor: other.anchor,
    rotation: other.rotation,
    flipH: other.flipH,
  );

  Slot copyWith({
    String? id,
    Object? photoId = _unset,
    Crop? crop,
    double? zoom,
    NormalizedPoint? anchor,
    QuarterTurn? rotation,
    bool? flipH,
  }) => Slot(
    id: id ?? this.id,
    photoId: identical(photoId, _unset) ? this.photoId : photoId as String?,
    crop: crop ?? this.crop,
    zoom: zoom == null ? this.zoom : zoom.clamp(minZoom, maxZoom).toDouble(),
    anchor: anchor ?? this.anchor,
    rotation: rotation ?? this.rotation,
    flipH: flipH ?? this.flipH,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    if (photoId != null) 'photoId': photoId,
    'crop': crop.toJson(),
    'zoom': zoom,
    'anchor': anchor.toJson(),
    if (!rotation.isNone) 'rotation': rotation.degrees,
    if (flipH) 'flipH': true,
  };

  factory Slot.fromJson(Object? json, String path) {
    final map = JsonRead.object(json, path);
    final zoom = JsonRead.number(map['zoom'], '$path.zoom');
    if (zoom < minZoom || zoom > maxZoom) {
      throw DesignFormatException(
        code: DesignFormatErrorCode.outOfRange,
        message: 'zoom must be within $minZoom..$maxZoom, got $zoom',
        path: '$path.zoom',
      );
    }
    final anchorJson = map['anchor'];
    final anchor = anchorJson == null
        ? NormalizedPoint.center
        : NormalizedPoint.fromJson(anchorJson, '$path.anchor');
    if (!anchor.isInsideUnitSquare) {
      throw DesignFormatException(
        code: DesignFormatErrorCode.outOfRange,
        message: 'anchor must be inside the 0..1 crop window',
        path: '$path.anchor',
      );
    }
    final cropJson = map['crop'];
    return Slot(
      id: JsonRead.id(map['id'], '$path.id'),
      photoId: JsonRead.optId(map['photoId'], '$path.photoId'),
      crop: cropJson == null
          ? Crop.full
          : Crop.fromJson(cropJson, '$path.crop'),
      zoom: zoom,
      anchor: anchor,
      rotation: _parseRotation(map['rotation'], '$path.rotation'),
      flipH: JsonRead.booleanOr(map['flipH'], '$path.flipH', fallback: false),
    );
  }

  static QuarterTurn _parseRotation(Object? value, String path) {
    if (value == null) return QuarterTurn.none;
    final degrees = JsonRead.integer(value, path);
    final turn = QuarterTurn.tryParse(degrees);
    if (turn == null) {
      throw DesignFormatException(
        code: DesignFormatErrorCode.outOfRange,
        message: 'rotation must be 0, 90, 180 or 270 degrees, got $degrees',
        path: path,
        args: <String, Object?>{'rotation': degrees},
      );
    }
    return turn;
  }

  @override
  bool operator ==(Object other) =>
      other is Slot &&
      other.id == id &&
      other.photoId == photoId &&
      other.crop == crop &&
      other.zoom == zoom &&
      other.anchor == anchor &&
      other.rotation == rotation &&
      other.flipH == flipH;

  @override
  int get hashCode =>
      Object.hash(id, photoId, crop, zoom, anchor, rotation, flipH);

  @override
  String toString() =>
      'Slot($id, photo: $photoId, zoom: $zoom, orientation: $orientationKey)';
}

@immutable
final class SlotRef {
  const SlotRef({
    required this.spreadId,
    required this.slotId,
    required this.photoId,
  });

  final String spreadId;

  final String slotId;

  final String photoId;

  @override
  bool operator ==(Object other) =>
      other is SlotRef &&
      other.spreadId == spreadId &&
      other.slotId == slotId &&
      other.photoId == photoId;

  @override
  int get hashCode => Object.hash(spreadId, slotId, photoId);

  @override
  String toString() => 'SlotRef($spreadId/$slotId → $photoId)';
}

const Object _unset = Object();
