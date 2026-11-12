import 'package:design_core/design_core.dart' hide TextAlign;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/features/_shared/application/design_session.dart';
import 'package:picpac_mobile/features/editor/presentation/editor_page.dart';
import 'package:picpac_mobile/features/editor/presentation/widgets/crop_handles.dart';

import '../support/design_fixtures.dart';
import '../support/design_harness.dart';

void main() {
  setUpAll(registerDesignFallbacks);

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('тап по кадру выбирает слот', (tester) async {
    useTallSurface(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 1);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester, location: '/editor/dsg_1');

    expect(find.text('Лист 1 из 1'), findsOneWidget);
    harness.container
        .read(designSessionProvider('dsg_1').notifier)
        .selectSlot('sheet_1', 'main');
    await tester.pump();

    final slot = harness.session!.selectedSlot;
    expect(slot?.id, 'main');
    expect(slot?.photoId, isNotNull);

    await _drain(tester, harness);
  });

  testWidgets('слот открывается по фокусу из preflight', (tester) async {
    useTallSurface(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 2);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(
      tester,
      location: '/editor/dsg_1',
      extra: const EditorFocus(spreadId: 'sheet_2', slotId: 'main'),
    );
    await harness.settleReal(tester);

    expect(harness.session!.selectedSpreadId, 'sheet_2');
    expect(harness.session!.selectedSlotId, 'main');
    expect(find.text('Лист 2 из 2'), findsOneWidget);

    await _drain(tester, harness);
  });

  testWidgets('слайдер масштаба — один шаг undo', (tester) async {
    useTallSurface(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 1);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester, location: '/editor/dsg_1');

    final notifier = harness.container.read(
      designSessionProvider('dsg_1').notifier,
    );
    notifier.selectSlot('sheet_1', 'main');
    await tester.pump();
    await tester.tap(find.text('Кадр'));
    await tester.pump();
    final before = harness.session!.document;
    final undoDepthBefore = harness.session!.canUndo;

    await tester.drag(find.byType(Slider), const Offset(80, 0));
    await harness.settleReal(tester);

    final after = harness.session!.document;
    expect(after.slotById('sheet_1', 'main')!.zoom, greaterThan(1));
    expect(after.revision, before.revision + 1);
    expect(undoDepthBefore, isFalse);

    notifier.undo();
    await harness.settleReal(tester);
    expect(harness.session!.document.slotById('sheet_1', 'main')!.zoom, 1);

    await _drain(tester, harness);
  });

  testWidgets('жест кадрирования коалесцируется в один шаг undo', (
    tester,
  ) async {
    useTallSurface(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 1);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester, location: '/editor/dsg_1');

    final notifier = harness.container.read(
      designSessionProvider('dsg_1').notifier,
    );
    notifier.selectSlot('sheet_1', 'main');
    final before = harness.session!.document;

    notifier.beginGesture('gesture.frame');
    for (var frame = 1; frame <= 20; frame++) {
      notifier.execute(
        SetCrop(
          spreadId: 'sheet_1',
          slotId: 'main',
          crop: Crop.full,
          zoom: 1 + frame / 20,
          anchor: const NormalizedPoint(0.5, 0.4),
        ),
      );
    }
    notifier.endGesture();

    final after = harness.session!.document;
    expect(after.slotById('sheet_1', 'main')!.zoom, closeTo(2, 0.001));
    expect(after.revision, before.revision + 1);

    notifier.undo();
    expect(
      harness.session!.document.slotById('sheet_1', 'main')!.zoom,
      1,
      reason: 'один шаг undo возвращает жест целиком',
    );

    await _drain(tester, harness);
  });

  testWidgets('ручки кропа доступны экранному диктору и работают', (
    tester,
  ) async {
    useTallSurface(tester);
    final handle = tester.ensureSemantics();
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 1);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester, location: '/editor/dsg_1');

    harness.container
        .read(designSessionProvider('dsg_1').notifier)
        .selectSlot('sheet_1', 'main');
    await tester.pump();
    await tester.tap(find.text('Кадр'));
    await harness.settleReal(tester);

    expect(find.byType(CropHandles), findsOneWidget);
    final handles = find.bySemanticsLabel(RegExp('Изменить кадр'));
    expect(handles, findsNWidgets(4));

    for (var i = 0; i < 4; i++) {
      final size = tester.getSize(handles.at(i));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }

    final before = harness.session!.document.slotById('sheet_1', 'main')!.crop;
    final start = tester.getCenter(handles.first);
    final gesture = await tester.startGesture(start);
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();
    await harness.settleReal(tester);
    final after = harness.session!.document.slotById('sheet_1', 'main')!.crop;
    expect(after.w, isNot(before.w));

    await _drain(tester, harness);
    handle.dispose();
  });
}

Future<void> _drain(WidgetTester tester, DesignHarness harness) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 3));
  await harness.settleReal(tester, frames: 4);
  await harness.disposeForTest(tester);
}
