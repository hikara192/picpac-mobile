import 'dart:typed_data';

import 'package:design_core/design_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/render/sheet_layout.dart';
import 'package:picpac_mobile/render/sheet_painter.dart';

import 'support/render_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const red = Color(0xFFFF0000);
  const green = Color(0xFF00FF00);
  const blue = Color(0xFF0000FF);
  const white = Color(0xFFFFFFFF);

  const renderSize = Size(160, 160);

  group('SheetLayout and orientation', () {
    test('a quarter turn fits the source to the inverse slot aspect', () async {
      final fixture = await RenderFixture.create(
        width: 20,
        height: 40,
        spec: const PrintSpec(widthMm: 50.8, heightMm: 25.4),
      );
      addTearDown(fixture.dispose);
      final layout = SheetLayout(
        spread: fixture.spread,
        template: BuiltInTemplates.single10x15,
        spec: fixture.spec,
        area: const Size(200, 100),
      );
      final slot = fixture.spread.slots.single;
      final straight = layout.sourceRectFor(
        slot: slot,
        imageSize: fixture.photoSize,
      );
      expect(straight.width, closeTo(20, 0.001));
      expect(straight.height, closeTo(10, 0.001));

      final turned = layout.sourceRectFor(
        slot: slot.copyWith(rotation: QuarterTurn.cw90),
        imageSize: fixture.photoSize,
      );
      expect(turned.width, closeTo(20, 0.001));
      expect(turned.height, closeTo(40, 0.001));
    });

    test('the untransformed quad swaps the axes on a quarter turn', () {
      const target = Rect.fromLTWH(10, 20, 60, 120);
      final slot = Slot(id: 'main', photoId: 'p0');
      final layout = SheetLayout(
        spread: Spread(
          id: 's',
          templateId: 't',
          background: SpreadBackground.color('#FFFFFF'),
          slots: <Slot>[slot],
        ),
        template: BuiltInTemplates.single10x15,
        spec: const PrintSpec(widthMm: 60, heightMm: 120),
        area: const Size(60, 120),
      );
      expect(layout.untransformedSize(slot, target), const Size(60, 120));
      expect(
        layout.untransformedSize(
          slot.copyWith(rotation: QuarterTurn.cw90),
          target,
        ),
        const Size(120, 60),
      );
    });

    test('visual corners map to the photo corner the user is editing', () {
      expect(
        photoCornerOf(
          CropCorner.topLeft,
          rotation: QuarterTurn.none,
          flipH: false,
        ),
        CropCorner.topLeft,
      );
      expect(
        photoCornerOf(
          CropCorner.topLeft,
          rotation: QuarterTurn.cw90,
          flipH: false,
        ),
        CropCorner.bottomLeft,
      );
      expect(
        photoCornerOf(
          CropCorner.topLeft,
          rotation: QuarterTurn.cw180,
          flipH: false,
        ),
        CropCorner.bottomRight,
      );
      expect(
        photoCornerOf(
          CropCorner.topLeft,
          rotation: QuarterTurn.cw270,
          flipH: false,
        ),
        CropCorner.topRight,
      );
      expect(
        photoCornerOf(
          CropCorner.topLeft,
          rotation: QuarterTurn.none,
          flipH: true,
        ),
        CropCorner.topRight,
      );
    });

    test('a drag delta follows the rotation and the mirror', () {
      const right = Offset(10, 0);
      expect(
        photoDeltaOf(right, rotation: QuarterTurn.none, flipH: false),
        right,
      );
      expect(
        photoDeltaOf(right, rotation: QuarterTurn.cw90, flipH: false),
        const Offset(0, -10),
      );
      expect(
        photoDeltaOf(right, rotation: QuarterTurn.cw180, flipH: false),
        const Offset(-10, 0),
      );
      expect(
        photoDeltaOf(right, rotation: QuarterTurn.cw270, flipH: false),
        const Offset(0, 10),
      );
      expect(
        photoDeltaOf(right, rotation: QuarterTurn.none, flipH: true),
        const Offset(-10, 0),
      );
    });

    test('every turn maps the four corners onto four distinct corners', () {
      for (final turn in QuarterTurn.values) {
        for (final flip in <bool>[false, true]) {
          final mapped = <CropCorner>{
            for (final corner in CropCorner.values)
              photoCornerOf(corner, rotation: turn, flipH: flip),
          };
          expect(mapped, hasLength(4), reason: '$turn / flip=$flip');
        }
      }
    });

    test('the framing hit-test undoes rotation, mirror and the cover fit', () {
      final slot = Slot(id: 'main', photoId: 'p0');
      final layout = SheetLayout(
        spread: Spread(
          id: 's',
          templateId: BuiltInTemplates.single10x15Id,
          background: SpreadBackground.color('#FFFFFF'),
          slots: <Slot>[slot],
        ),
        template: BuiltInTemplates.single10x15,
        spec: const PrintSpec(widthMm: 25.4, heightMm: 25.4),
        area: const Size(100, 100),
      );
      const imageSize = Size(40, 40);
      final target = layout.rectOf('main');

      expect(
        layout.photoPointAt('main', target.center, imageSize: imageSize),
        NormalizedPoint.center,
      );
      final topLeft = layout.photoPointAt(
        'main',
        target.topLeft + const Offset(1, 1),
        imageSize: imageSize,
      )!;
      expect(topLeft.x, closeTo(0, 0.05));
      expect(topLeft.y, closeTo(0, 0.05));

      final turned = layout.spread.copyWith(
        slots: <Slot>[slot.copyWith(rotation: QuarterTurn.cw90)],
      );
      final turnedLayout = SheetLayout(
        spread: turned,
        template: BuiltInTemplates.single10x15,
        spec: const PrintSpec(widthMm: 25.4, heightMm: 25.4),
        area: const Size(100, 100),
      );
      final turnedTopLeft = turnedLayout.photoPointAt(
        'main',
        target.topLeft + const Offset(1, 1),
        imageSize: imageSize,
      )!;
      expect(turnedTopLeft.x, closeTo(0, 0.05));
      expect(turnedTopLeft.y, closeTo(1, 0.05));

      final mirrored = layout.spread.copyWith(
        slots: <Slot>[slot.copyWith(flipH: true)],
      );
      final mirroredLayout = SheetLayout(
        spread: mirrored,
        template: BuiltInTemplates.single10x15,
        spec: const PrintSpec(widthMm: 25.4, heightMm: 25.4),
        area: const Size(100, 100),
      );
      final mirroredTopLeft = mirroredLayout.photoPointAt(
        'main',
        target.topLeft + const Offset(1, 1),
        imageSize: imageSize,
      )!;
      expect(mirroredTopLeft.x, closeTo(1, 0.05));
      expect(mirroredTopLeft.y, closeTo(0, 0.05));

      expect(
        layout.photoPointAt('main', const Offset(-5, -5), imageSize: imageSize),
        isNull,
      );
    });
  });

  group('painted orientation', () {
    Future<Uint8List> render(QuarterTurn rotation, {bool flipH = false}) async {
      final fixture = await RenderFixture.create(
        slots: (photoId) => <Slot>[
          Slot(id: 'main', photoId: photoId, rotation: rotation, flipH: flipH),
        ],
      );
      addTearDown(fixture.dispose);
      final layout = SheetLayout(
        spread: fixture.spread,
        template: fixture.template,
        spec: fixture.spec,
        area: renderSize,
      );
      final image = await renderSheetToImage(
        layout: layout,
        document: fixture.document,
        images: fixture.store,
        pixelSize: renderSize,
      );
      addTearDown(image!.dispose);
      return rawPixels(image);
    }

    Color sample(Uint8List pixels, int x, int y) => pixelAt(pixels, 160, x, y);

    test('without a turn the sheet shows the photo as is', () async {
      final pixels = await render(QuarterTurn.none);
      expect(colorWithin(sample(pixels, 20, 20), red), isTrue);
      expect(colorWithin(sample(pixels, 140, 20), green), isTrue);
      expect(colorWithin(sample(pixels, 20, 140), blue), isTrue);
      expect(colorWithin(sample(pixels, 140, 140), white), isTrue);
    });

    test('90° moves the photo bottom-left to the sheet top-left', () async {
      final pixels = await render(QuarterTurn.cw90);
      expect(colorWithin(sample(pixels, 20, 20), blue), isTrue);
      expect(colorWithin(sample(pixels, 140, 20), red), isTrue);
      expect(colorWithin(sample(pixels, 20, 140), white), isTrue);
      expect(colorWithin(sample(pixels, 140, 140), green), isTrue);
    });

    test('180° swaps the diagonals', () async {
      final pixels = await render(QuarterTurn.cw180);
      expect(colorWithin(sample(pixels, 20, 20), white), isTrue);
      expect(colorWithin(sample(pixels, 140, 140), red), isTrue);
    });

    test('270° moves the photo top-right to the sheet top-left', () async {
      final pixels = await render(QuarterTurn.cw270);
      expect(colorWithin(sample(pixels, 20, 20), green), isTrue);
      expect(colorWithin(sample(pixels, 140, 20), white), isTrue);
    });

    test('a mirror swaps left and right only', () async {
      final pixels = await render(QuarterTurn.none, flipH: true);
      expect(colorWithin(sample(pixels, 20, 20), green), isTrue);
      expect(colorWithin(sample(pixels, 140, 20), red), isTrue);
      expect(colorWithin(sample(pixels, 20, 140), white), isTrue);
      expect(colorWithin(sample(pixels, 140, 140), blue), isTrue);
    });

    test('a mirror and a quarter turn compose as documented', () async {
      final pixels = await render(QuarterTurn.cw90, flipH: true);
      expect(colorWithin(sample(pixels, 20, 20), white), isTrue);
    });
  });
}
