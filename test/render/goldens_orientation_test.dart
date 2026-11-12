import 'dart:ui' as ui;

import 'package:design_core/design_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/render/sheet_layout.dart';
import 'package:picpac_mobile/render/sheet_painter.dart';

import 'support/render_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const goldenSize = Size(300, 450);

  Future<Future<List<int>>> render({
    QuarterTurn rotation = QuarterTurn.none,
    bool flipH = false,
    PhotoAdjustment adjustment = PhotoAdjustment.neutral,
    int width = 60,
    int height = 90,
  }) async {
    final fixture = await RenderFixture.create(
      width: width,
      height: height,
      spec: const PrintSpec(widthMm: 100, heightMm: 150),
      slots: (photoId) => <Slot>[
        Slot(id: 'main', photoId: photoId, rotation: rotation, flipH: flipH),
      ],
    );
    addTearDown(fixture.dispose);
    final document = adjustment.isNeutral
        ? fixture.document
        : fixture.document.copyWith(
            photoAdjustments: <String, PhotoAdjustment>{'p0': adjustment},
          );
    final layout = SheetLayout(
      spread: document.spreads.first,
      template: fixture.template,
      spec: fixture.spec,
      area: goldenSize,
    );
    final image = await renderSheetToImage(
      layout: layout,
      document: document,
      images: fixture.store,
      pixelSize: goldenSize,
    );
    addTearDown(image!.dispose);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return Future<List<int>>.value(data!.buffer.asUint8List());
  }

  test('golden: слот повёрнут на 90°', () async {
    final png = await render(rotation: QuarterTurn.cw90);
    await expectLater(png, matchesGoldenFile('goldens/slot_rotated_90.png'));
  });

  test('golden: слот отражён по горизонтали', () async {
    final png = await render(flipH: true);
    await expectLater(png, matchesGoldenFile('goldens/slot_flipped.png'));
  });

  test('golden: слот с look «Ч/Б»', () async {
    final png = await render(
      adjustment: const PhotoAdjustment(
        exposure: 0.15,
        look: LookSetting(id: 'mono', strength: 1),
      ),
    );
    await expectLater(png, matchesGoldenFile('goldens/slot_look_mono.png'));
  });

  test('golden: поворот 180° с look «Плёнка»', () async {
    final png = await render(
      rotation: QuarterTurn.cw180,
      flipH: true,
      adjustment: const PhotoAdjustment(
        look: LookSetting(id: 'film', strength: 0.6),
      ),
    );
    await expectLater(
      png,
      matchesGoldenFile('goldens/slot_rotated_180_film.png'),
    );
  });
}
