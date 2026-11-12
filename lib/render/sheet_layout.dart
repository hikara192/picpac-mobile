import 'dart:math' as math;

import 'package:design_core/design_core.dart';
import 'package:flutter/rendering.dart';

final class SheetLayout {
  SheetLayout({
    required this.spread,
    required this.template,
    required this.spec,
    required this.area,
  });

  final Spread spread;

  final PrintTemplate template;

  final PrintSpec spec;

  final Size area;

  double get aspect {
    final height = spec.effectiveSpreadHeightMm;
    if (height <= 0) return 1;
    return spec.effectiveSpreadWidthMm / height;
  }

  late final Rect sheetRect = _fit(area, aspect);

  Rect rectOf(String slotId) {
    final slot = template.slotById(slotId);
    if (slot == null) return Rect.zero;
    final rect = sheetRect;
    return Rect.fromLTWH(
      rect.left + slot.rect.x * rect.width,
      rect.top + slot.rect.y * rect.height,
      slot.rect.w * rect.width,
      slot.rect.h * rect.height,
    );
  }

  Rect safeRectOf(String slotId) {
    final slot = template.slotById(slotId);
    if (slot == null) return Rect.zero;
    final rect = sheetRect;
    final inset = slot.safeInset;
    return Rect.fromLTWH(
      rect.left + (slot.rect.x + inset) * rect.width,
      rect.top + (slot.rect.y + inset) * rect.height,
      (slot.rect.w - 2 * inset) * rect.width,
      (slot.rect.h - 2 * inset) * rect.height,
    );
  }

  Rect get safeBox {
    final rect = sheetRect;
    final insetX = spec.safeWidthFraction * rect.width;
    final insetY = spec.safeHeightFraction * rect.height;
    return Rect.fromLTWH(
      rect.left + insetX,
      rect.top + insetY,
      rect.width - 2 * insetX,
      rect.height - 2 * insetY,
    );
  }

  Rect sourceRectFor({required Slot slot, required Size imageSize}) {
    final window = slot.effectiveSourceWindow;
    final windowRect = Rect.fromLTWH(
      window.x * imageSize.width,
      window.y * imageSize.height,
      window.w * imageSize.width,
      window.h * imageSize.height,
    );
    final target = rectOf(slot.id);
    if (target.isEmpty || windowRect.isEmpty) return windowRect;
    final slotAspect = slot.rotation.swapsAxes
        ? target.height / target.width
        : target.width / target.height;
    if (slotAspect <= 0 || !slotAspect.isFinite) return windowRect;
    final windowAspect = windowRect.width / windowRect.height;
    if ((windowAspect - slotAspect).abs() < 1e-4) return windowRect;
    if (windowAspect > slotAspect) {
      final width = windowRect.height * slotAspect;
      return Rect.fromLTWH(
        windowRect.center.dx - width / 2,
        windowRect.top,
        width,
        windowRect.height,
      );
    }
    final height = windowRect.width / slotAspect;
    return Rect.fromLTWH(
      windowRect.left,
      windowRect.center.dy - height / 2,
      windowRect.width,
      height,
    );
  }

  Size untransformedSize(Slot slot, Rect target) =>
      slot.rotation.swapsAxes ? Size(target.height, target.width) : target.size;

  CropCorner photoCornerFor(String slotId, CropCorner corner) {
    final slot = spread.slotById(slotId);
    if (slot == null) return corner;
    return photoCornerOf(corner, rotation: slot.rotation, flipH: slot.flipH);
  }

  NormalizedPoint? photoPointAt(
    String slotId,
    Offset scenePoint, {
    required Size imageSize,
  }) {
    final slot = spread.slotById(slotId);
    if (slot == null) return null;
    final target = rectOf(slotId);
    if (target.isEmpty || !target.contains(scenePoint)) return null;
    if (imageSize.width <= 0 || imageSize.height <= 0) return null;

    final u = ((scenePoint.dx - target.left) / target.width).clamp(0.0, 1.0);
    final v = ((scenePoint.dy - target.top) / target.height).clamp(0.0, 1.0);
    final local = switch (slot.rotation) {
      QuarterTurn.none => Offset(u, v),
      QuarterTurn.cw90 => Offset(v, 1 - u),
      QuarterTurn.cw180 => Offset(1 - u, 1 - v),
      QuarterTurn.cw270 => Offset(1 - v, u),
    };
    final x = slot.flipH ? 1 - local.dx : local.dx;
    final y = local.dy;

    final source = sourceRectFor(slot: slot, imageSize: imageSize);
    return NormalizedPoint(
      ((source.left + x * source.width) / imageSize.width).clamp(0.0, 1.0),
      ((source.top + y * source.height) / imageSize.height).clamp(0.0, 1.0),
    );
  }

  Crop visibleWindow(Slot slot, Size imageSize) {
    if (imageSize.width <= 0 || imageSize.height <= 0) {
      return slot.effectiveSourceWindow;
    }
    final source = sourceRectFor(slot: slot, imageSize: imageSize);
    final width = source.width / imageSize.width;
    final height = source.height / imageSize.height;
    return Crop(
      x: (source.left / imageSize.width).clamp(0, 1 - width).toDouble(),
      y: (source.top / imageSize.height).clamp(0, 1 - height).toDouble(),
      w: width.clamp(0, 1).toDouble(),
      h: height.clamp(0, 1).toDouble(),
    ).clamped();
  }

  String? slotAt(Offset point) {
    for (var i = template.slots.length - 1; i >= 0; i--) {
      final slot = template.slots[i];
      if (rectOf(slot.id).contains(point)) return slot.id;
    }
    return null;
  }

  int indexOfSlot(String slotId) =>
      template.slots.indexWhere((slot) => slot.id == slotId);

  Map<CropCorner, Offset> handlesOf(String slotId) {
    final rect = rectOf(slotId);
    return <CropCorner, Offset>{
      CropCorner.topLeft: rect.topLeft,
      CropCorner.topRight: rect.topRight,
      CropCorner.bottomLeft: rect.bottomLeft,
      CropCorner.bottomRight: rect.bottomRight,
    };
  }

  static Rect _fit(Size area, double aspect) {
    if (area.isEmpty) return Rect.zero;
    var width = area.width;
    var height = width / aspect;
    if (height > area.height) {
      height = area.height;
      width = height * aspect;
    }
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      return Rect.zero;
    }
    return Rect.fromLTWH(
      (area.width - width) / 2,
      (area.height - height) / 2,
      width,
      height,
    );
  }
}

enum CropCorner {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight;

  CropCorner get opposite => switch (this) {
    CropCorner.topLeft => CropCorner.bottomRight,
    CropCorner.topRight => CropCorner.bottomLeft,
    CropCorner.bottomLeft => CropCorner.topRight,
    CropCorner.bottomRight => CropCorner.topLeft,
  };

  double get dx => switch (this) {
    CropCorner.topLeft || CropCorner.bottomLeft => -1,
    CropCorner.topRight || CropCorner.bottomRight => 1,
  };

  double get dy => switch (this) {
    CropCorner.topLeft || CropCorner.topRight => -1,
    CropCorner.bottomLeft || CropCorner.bottomRight => 1,
  };

  CropCorner get mirrorHorizontal => switch (this) {
    CropCorner.topLeft => CropCorner.topRight,
    CropCorner.topRight => CropCorner.topLeft,
    CropCorner.bottomLeft => CropCorner.bottomRight,
    CropCorner.bottomRight => CropCorner.bottomLeft,
  };
}

const double kMinHandleCrop = 0.05;

Crop clampCropWindow({required Crop crop, double minSize = kMinHandleCrop}) {
  final width = crop.w.clamp(minSize, 1.0).toDouble();
  final height = crop.h.clamp(minSize, 1.0).toDouble();
  return Crop(
    x: crop.x.clamp(0, 1 - width).toDouble(),
    y: crop.y.clamp(0, 1 - height).toDouble(),
    w: width,
    h: height,
  );
}

Rect rectOfCrop(Crop crop, Size imageSize) => Rect.fromLTWH(
  crop.x * imageSize.width,
  crop.y * imageSize.height,
  crop.w * imageSize.width,
  crop.h * imageSize.height,
);

CropCorner photoCornerOf(
  CropCorner visualCorner, {
  required QuarterTurn rotation,
  required bool flipH,
}) {
  final photo = switch (rotation) {
    QuarterTurn.none => visualCorner,
    QuarterTurn.cw90 => switch (visualCorner) {
      CropCorner.topLeft => CropCorner.bottomLeft,
      CropCorner.topRight => CropCorner.topLeft,
      CropCorner.bottomRight => CropCorner.topRight,
      CropCorner.bottomLeft => CropCorner.bottomRight,
    },
    QuarterTurn.cw180 => visualCorner.opposite,
    QuarterTurn.cw270 => switch (visualCorner) {
      CropCorner.topLeft => CropCorner.topRight,
      CropCorner.topRight => CropCorner.bottomRight,
      CropCorner.bottomRight => CropCorner.bottomLeft,
      CropCorner.bottomLeft => CropCorner.topLeft,
    },
  };
  return flipH ? photo.mirrorHorizontal : photo;
}

Offset photoDeltaOf(
  Offset visualDelta, {
  required QuarterTurn rotation,
  required bool flipH,
}) {
  final photo = switch (rotation) {
    QuarterTurn.none => visualDelta,
    QuarterTurn.cw90 => Offset(visualDelta.dy, -visualDelta.dx),
    QuarterTurn.cw180 => -visualDelta,
    QuarterTurn.cw270 => Offset(-visualDelta.dy, visualDelta.dx),
  };
  return flipH ? Offset(-photo.dx, photo.dy) : photo;
}

bool almostEqual(double a, double b, [double epsilon = kUnitEpsilon]) =>
    (a - b).abs() <= epsilon;

double aspectOfMillimetres(PrintSpec spec) {
  final height = spec.effectiveSpreadHeightMm;
  if (height <= 0) return 1;
  return math.max(spec.effectiveSpreadWidthMm, kUnitEpsilon) / height;
}
