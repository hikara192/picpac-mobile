import 'package:design_core/design_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/features/editor/application/frame_gesture.dart';
import 'package:picpac_mobile/render/sheet_layout.dart';

void main() {
  const slotSize = Size(300, 450);

  group('pan и zoom', () {
    test('масштаб умножается и ограничен 1..8', () {
      final base = Slot(id: 'main', photoId: 'p', zoom: 2);

      expect(
        FrameGesture.panAndZoom(
          base: base,
          panPixels: Offset.zero,
          scale: 1.5,
          slotSize: slotSize,
        ).zoom,
        3,
      );
      expect(
        FrameGesture.panAndZoom(
          base: base,
          panPixels: Offset.zero,
          scale: 100,
          slotSize: slotSize,
        ).zoom,
        Slot.maxZoom,
      );
      expect(
        FrameGesture.panAndZoom(
          base: base,
          panPixels: Offset.zero,
          scale: 0.01,
          slotSize: slotSize,
        ).zoom,
        Slot.minZoom,
      );
    });

    test('фото следует за пальцем: вправо — якорь влево', () {
      final base = Slot(id: 'main', photoId: 'p', zoom: 2);
      final moved = FrameGesture.panAndZoom(
        base: base,
        panPixels: const Offset(60, 0),
        scale: 1,
        slotSize: slotSize,
      );
      expect(moved.anchor.x, lessThan(base.anchor.x));
      expect(moved.anchor.y, closeTo(base.anchor.y, 1e-9));
    });

    test('без запаса панорамирование не выдумывает смещение', () {
      final base = Slot(id: 'main', photoId: 'p');
      final moved = FrameGesture.panAndZoom(
        base: base,
        panPixels: const Offset(200, 200),
        scale: 1,
        slotSize: slotSize,
      );
      expect(moved.zoom, 1);
      expect(moved.anchor, NormalizedPoint.center);
    });

    test('якорь всегда внутри 0..1', () {
      final base = Slot(
        id: 'main',
        photoId: 'p',
        zoom: 4,
        anchor: const NormalizedPoint(0.5, 0.5),
      );
      final moved = FrameGesture.panAndZoom(
        base: base,
        panPixels: const Offset(-5000, 5000),
        scale: 1,
        slotSize: slotSize,
      );
      expect(moved.anchor.x, inInclusiveRange(0, 1));
      expect(moved.anchor.y, inInclusiveRange(0, 1));
    });
  });

  group('ручки кадрирования', () {
    test('перетаскивание внутрь уменьшает окно с сохранением пропорций', () {
      const base = Crop.full;
      final resized = FrameGesture.resize(
        base: base,
        corner: CropCorner.topLeft,
        deltaPixels: const Offset(60, 90),
        slotSize: slotSize,
      );
      expect(resized.w, lessThan(1));
      expect(resized.h, lessThan(1));
      expect(resized.w / base.w, closeTo(resized.h / base.h, 1e-6));
      expect(resized.right, closeTo(1, 1e-9));
      expect(resized.bottom, closeTo(1, 1e-9));
    });

    test('окно не выходит за фото и не становится меньше минимума', () {
      final tiny = FrameGesture.resize(
        base: const Crop(x: 0.2, y: 0.2, w: 0.3, h: 0.3),
        corner: CropCorner.bottomRight,
        deltaPixels: const Offset(100000, 100000),
        slotSize: slotSize,
      );
      expect(tiny.w, lessThanOrEqualTo(1));
      expect(tiny.h, lessThanOrEqualTo(1));
      expect(tiny.x + tiny.w, lessThanOrEqualTo(1 + kUnitEpsilon));
      expect(tiny.isValid, isTrue);
    });

    test('вытягивание наружу упирается в границу 1.0', () {
      final grown = FrameGesture.resize(
        base: const Crop(x: 0.1, y: 0.1, w: 0.5, h: 0.5),
        corner: CropCorner.topLeft,
        deltaPixels: const Offset(-400, -400),
        slotSize: slotSize,
      );
      expect(grown.isValid, isTrue);
      expect(grown.x, greaterThanOrEqualTo(0));
      expect(grown.y, greaterThanOrEqualTo(0));
      expect(grown.right, lessThanOrEqualTo(1 + kUnitEpsilon));
    });
  });
}
