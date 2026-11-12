import 'package:design_core/design_core.dart' hide TextAlign;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/features/_shared/application/design_session.dart';
import 'package:picpac_mobile/features/_shared/presentation/sheet_scene.dart';
import 'package:picpac_mobile/features/editor/application/frame_gesture.dart';
import 'package:picpac_mobile/features/editor/presentation/widgets/crop_handles.dart';
import 'package:picpac_mobile/render/sheet_layout.dart';

import '../support/design_fixtures.dart';
import '../support/design_harness.dart';

void main() {
  setUpAll(registerDesignFallbacks);

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<DesignHarness> quadEditor(
    WidgetTester tester, {
    QuarterTurn rotation = QuarterTurn.none,
    bool flipH = false,
    double zoom = 1,
  }) async {
    final harness = await DesignHarness.forWidgetTest(
      tester,
      format: printFormat(quadFirst: true),
    );
    final document = await harness.seedPhotosForTest(tester, count: 4);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester, location: '/editor/dsg_1');

    final controller = harness.container.read(
      designSessionProvider('dsg_1').notifier,
    );
    controller.selectSlot('sheet_1', 'tl');
    await tester.pump();
    if (rotation != QuarterTurn.none || flipH) {
      controller.execute(
        SetSlotOrientation.turn(
          spreadId: 'sheet_1',
          slotId: 'tl',
          rotation: rotation,
          flipH: flipH,
        ),
      );
    }
    if (zoom != 1) {
      final slot = harness.session!.document.slotById('sheet_1', 'tl')!;
      controller.execute(
        SetCrop(
          spreadId: 'sheet_1',
          slotId: 'tl',
          crop: slot.crop,
          zoom: zoom,
          anchor: NormalizedPoint.center,
        ),
      );
    }
    await harness.settleReal(tester);

    await tester.ensureVisible(find.text('Кадр'));
    await tester.tap(find.text('Кадр'));
    await harness.settleReal(tester);
    return harness;
  }

  Slot slotOf(DesignHarness harness) =>
      harness.session!.document.slotById('sheet_1', 'tl')!;

  Crop cropOf(DesignHarness harness) => slotOf(harness).crop;

  SheetLayout layoutOf(WidgetTester tester) =>
      tester.widget<CropHandles>(find.byType(CropHandles)).layout;

  Future<void> dragHandle(
    WidgetTester tester,
    String corner, {
    required Offset total,
    Offset firstMove = const Offset(30, 30),
  }) async {
    final finder = find.bySemanticsLabel('Изменить кадр, угол $corner');
    expect(finder, findsOneWidget, reason: 'ручка «$corner»');
    final start = tester.getCenter(finder);
    final gesture = await tester.startGesture(start);
    await tester.pump();
    await gesture.moveBy(firstMove);
    await tester.pump(const Duration(milliseconds: 16));
    final rest = total - firstMove;
    const step = 2;
    for (var i = 0; i < step; i++) {
      await gesture.moveBy(rest / step.toDouble());
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();
  }

  testWidgets('90°: ручка левого верха двигает только фото по x', (
    tester,
  ) async {
    useTallSurface(tester);
    final semantics = tester.ensureSemantics();
    final harness = await quadEditor(tester, rotation: QuarterTurn.cw90);

    await dragHandle(tester, 'левый верхний', total: const Offset(50, 50));
    await harness.settleReal(tester);

    final crop = cropOf(harness);
    expect(
      crop.y,
      closeTo(0, 1e-9),
      reason: 'на повёрнутом фото верхняя кромка в кадре не участвует',
    );
    expect(crop.x, greaterThan(0.01), reason: 'окно сжалось по x');
    expect(crop.w, lessThan(1));
    expect(crop.x + crop.w, closeTo(1, 1e-9));
    expect(crop.y, closeTo(0, 1e-9));

    await _drain(tester, harness);
    semantics.dispose();
  });

  testWidgets('0°: та же ручка двигает и x, и y', (tester) async {
    useTallSurface(tester);
    final semantics = tester.ensureSemantics();
    final harness = await quadEditor(tester);

    await dragHandle(tester, 'левый верхний', total: const Offset(50, 50));
    await harness.settleReal(tester);

    final crop = cropOf(harness);
    expect(crop.x, greaterThan(0.01));
    expect(
      crop.y,
      greaterThan(0.01),
      reason: 'без поворота левый верхний угол фото и есть верхняя кромка',
    );
    expect(crop.x + crop.w, closeTo(1, 1e-9));
    expect(crop.y + crop.h, closeTo(1, 1e-9));

    await _drain(tester, harness);
    semantics.dispose();
  });

  testWidgets('90°: пан вправо двигает фото вбок, а не вверх', (tester) async {
    useTallSurface(tester);
    final harness = await quadEditor(
      tester,
      rotation: QuarterTurn.cw90,
      zoom: 2,
    );
    final layout = layoutOf(tester);
    final target = layout.rectOf('tl');
    final slot = slotOf(harness);
    final asset = harness.session!.document.assetById(slot.photoId!)!;
    final imageSize = Size(asset.widthPx.toDouble(), asset.heightPx.toDouble());
    final before = layout.photoPointAt(
      'tl',
      target.center,
      imageSize: imageSize,
    )!;

    await panScene(tester, from: target.center, by: const Offset(80, 0));
    await harness.settleReal(tester);

    final updated = layoutOf(tester);
    final after = updated.photoPointAt(
      'tl',
      updated.rectOf('tl').center,
      imageSize: imageSize,
    )!;
    expect(
      after.x,
      closeTo(before.x, 1e-6),
      reason: 'пан вправо не должен сдвигать фото по x кадра',
    );
    expect(
      after.y,
      greaterThan(before.y + 0.01),
      reason: 'фото уехало вбок: под центром слота другая полоса снимка',
    );

    await _drain(tester, harness);
  });

  testWidgets('flipH: левая ручка правит правый край фото', (tester) async {
    useTallSurface(tester);
    final semantics = tester.ensureSemantics();
    final harness = await quadEditor(tester, flipH: true);

    await dragHandle(tester, 'левый верхний', total: const Offset(50, 50));
    await harness.settleReal(tester);

    final crop = cropOf(harness);
    expect(
      crop.x,
      closeTo(0, 1e-9),
      reason: 'при отражении левая ручка двигает правый край фото',
    );
    expect(crop.w, lessThan(1));
    expect(crop.y, greaterThan(0.01));

    await _drain(tester, harness);
    semantics.dispose();
  });

  testWidgets('0° без отражения: прежний результат байт-в-байт', (
    tester,
  ) async {
    useTallSurface(tester);
    final semantics = tester.ensureSemantics();
    final harness = await quadEditor(tester);
    final slotSize = layoutOf(tester).rectOf('tl').size;

    await dragHandle(tester, 'левый верхний', total: const Offset(50, 50));
    await harness.settleReal(tester);

    final expected = FrameGesture.resize(
      base: Crop.full,
      corner: CropCorner.topLeft,
      deltaPixels: const Offset(20, 20),
      slotSize: slotSize,
    );
    final actual = cropOf(harness);
    expect(actual.x, closeTo(expected.x, 1e-12));
    expect(actual.y, closeTo(expected.y, 1e-12));
    expect(actual.w, closeTo(expected.w, 1e-12));
    expect(actual.h, closeTo(expected.h, 1e-12));

    await _drain(tester, harness);
    semantics.dispose();
  });

  testWidgets('после поворота все четыре ручки — цели ≥48 dp', (tester) async {
    useTallSurface(tester);
    final semantics = tester.ensureSemantics();
    final harness = await quadEditor(tester, rotation: QuarterTurn.cw90);

    final handles = find.bySemanticsLabel(RegExp('Изменить кадр'));
    expect(handles, findsNWidgets(4));
    for (var i = 0; i < 4; i++) {
      final size = tester.getSize(handles.at(i));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    final rect = layoutOf(tester).rectOf('tl');
    for (var i = 0; i < 4; i++) {
      final center = tester.getCenter(handles.at(i));
      final local = center - tester.getTopLeft(find.byType(CropHandles));
      expect(local.dx, inInclusiveRange(rect.left - 24, rect.right + 24));
      expect(local.dy, inInclusiveRange(rect.top - 24, rect.bottom + 24));
    }

    await _drain(tester, harness);
    semantics.dispose();
  });
}

Future<void> panScene(
  WidgetTester tester, {
  required Offset from,
  required Offset by,
}) async {
  final origin = tester.getTopLeft(find.byType(SheetScene)) + from;
  final gesture = await tester.startGesture(origin);
  await tester.pump();
  for (var i = 0; i < 4; i++) {
    await gesture.moveBy(by / 4);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pump();
}

Future<void> _drain(WidgetTester tester, DesignHarness harness) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 3));
  await harness.settleReal(tester, frames: 4);
  await harness.disposeForTest(tester);
}
