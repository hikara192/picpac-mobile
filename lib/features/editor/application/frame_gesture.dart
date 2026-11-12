import 'dart:math' as math;

import 'package:design_core/design_core.dart';
import 'package:flutter/rendering.dart';

import '../../../render/sheet_layout.dart';

final class FrameTransform {
  const FrameTransform({required this.zoom, required this.anchor});

  final double zoom;

  final NormalizedPoint anchor;
}

abstract final class FrameGesture {
  static FrameTransform panAndZoom({
    required Slot base,
    required Offset panPixels,
    required double scale,
    required Size slotSize,
  }) {
    final safeScale = scale.isFinite && scale > 0 ? scale : 1.0;
    final zoom = (base.zoom * safeScale)
        .clamp(Slot.minZoom, Slot.maxZoom)
        .toDouble();
    if (slotSize.width <= 0 || slotSize.height <= 0) {
      return FrameTransform(zoom: zoom, anchor: base.anchor);
    }

    final crop = base.crop;
    final windowWidth = crop.w / zoom;
    final windowHeight = crop.h / zoom;
    final startLeft = crop.x + (crop.w - windowWidth) * base.anchor.x;
    final startTop = crop.y + (crop.h - windowHeight) * base.anchor.y;

    final dx = -panPixels.dx / slotSize.width * windowWidth;
    final dy = -panPixels.dy / slotSize.height * windowHeight;
    final roomX = crop.w - windowWidth;
    final roomY = crop.h - windowHeight;
    final anchorX = roomX <= kUnitEpsilon
        ? 0.5
        : ((startLeft + dx - crop.x) / roomX).clamp(0.0, 1.0).toDouble();
    final anchorY = roomY <= kUnitEpsilon
        ? 0.5
        : ((startTop + dy - crop.y) / roomY).clamp(0.0, 1.0).toDouble();

    return FrameTransform(
      zoom: zoom,
      anchor: NormalizedPoint(anchorX, anchorY),
    );
  }

  static Crop resize({
    required Crop base,
    required CropCorner corner,
    required Offset deltaPixels,
    required Size slotSize,
    double minSize = kMinHandleCrop,
  }) {
    if (slotSize.width <= 0 || slotSize.height <= 0) return base;
    final perPixelX = base.w / slotSize.width;
    final perPixelY = base.h / slotSize.height;
    final wantedWidth = base.w + deltaPixels.dx * perPixelX * corner.dx;
    final wantedHeight = base.h + deltaPixels.dy * perPixelY * corner.dy;
    final rawScale = math.max(wantedWidth / base.w, wantedHeight / base.h);
    final maxScale = math.min(1 / base.w, 1 / base.h);
    final minScale = math.max(minSize / base.w, minSize / base.h);
    final scale = rawScale.clamp(minScale, maxScale).toDouble();

    final width = base.w * scale;
    final height = base.h * scale;
    final double left;
    final double top;
    switch (corner) {
      case CropCorner.topLeft:
        left = base.right - width;
        top = base.bottom - height;
      case CropCorner.topRight:
        left = base.x;
        top = base.bottom - height;
      case CropCorner.bottomLeft:
        left = base.right - width;
        top = base.y;
      case CropCorner.bottomRight:
        left = base.x;
        top = base.y;
    }
    return clampCropWindow(
      crop: Crop(x: left, y: top, w: width, h: height),
      minSize: minSize,
    );
  }
}
