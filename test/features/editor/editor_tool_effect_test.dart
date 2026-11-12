import 'package:design_core/design_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/features/_shared/application/design_session.dart';
import 'package:picpac_mobile/features/_shared/presentation/sheet_scene.dart';

import '../support/design_fixtures.dart';
import '../support/design_harness.dart';

void main() {
  setUpAll(registerDesignFallbacks);

  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Map<String, Object?> body(DesignDocument document) {
    final json = document.toJson();
    json.remove('revision');
    return json;
  }

  DesignSessionController controllerOf(DesignHarness harness) =>
      harness.container.read(designSessionProvider('dsg_1').notifier);

  Future<void> expectToolChangesDocument(
    WidgetTester tester,
    DesignHarness harness, {
    required String tool,
    required Future<void> Function() act,
  }) async {
    final before = harness.session!.document;
    final beforeBody = body(before);

    await tester.ensureVisible(find.text(tool));
    await tester.tap(find.text(tool));
    await harness.settleReal(tester);

    await act();
    await harness.settleReal(tester);

    final changed = harness.session!.document;
    expect(
      body(changed),
      isNot(equals(beforeBody)),
      reason: 'инструмент «$tool» должен менять документ',
    );
    expect(controllerOf(harness).undo(), isTrue, reason: 'undo «$tool»');
    await harness.settleReal(tester);
    expect(
      body(harness.session!.document),
      equals(beforeBody),
      reason: 'один undo возвращает состояние до «$tool»',
    );
  }

  Future<DesignHarness> editorWith(
    WidgetTester tester, {
    int photos = 1,
    bool quad = false,
  }) async {
    final harness = await DesignHarness.forWidgetTest(
      tester,
      format: printFormat(quadFirst: quad),
    );
    final document = await harness.seedPhotosForTest(tester, count: photos);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester, location: '/editor/dsg_1');
    return harness;
  }

  testWidgets('«Кадр»: зум меняет слот и откатывается', (tester) async {
    usePhoneSurface(tester);
    final harness = await editorWith(tester);

    await expectToolChangesDocument(
      tester,
      harness,
      tool: 'Кадр',
      act: () async {
        await tester.drag(find.byType(Slider), const Offset(80, 0));
        await harness.settleReal(tester);
        final slot = harness.session!.document.slotById('sheet_1', 'main')!;
        expect(slot.zoom, greaterThan(Slot.minZoom));
      },
    );

    await _drain(tester, harness);
  });

  testWidgets('«Свет»: EV меняет кадр и откатывается', (tester) async {
    usePhoneSurface(tester);
    final harness = await editorWith(tester);

    await expectToolChangesDocument(
      tester,
      harness,
      tool: 'Свет',
      act: () async {
        await tester.drag(find.byType(Slider), const Offset(70, 0));
        await harness.settleReal(tester);
        final photoId = harness.session!.document.assets.first.id;
        expect(
          harness.session!.document.adjustmentFor(photoId).exposure,
          isNot(0),
        );
      },
    );

    await _drain(tester, harness);
  });

  testWidgets('«Тепло»: температура меняет кадр и откатывается', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final harness = await editorWith(tester);

    await expectToolChangesDocument(
      tester,
      harness,
      tool: 'Тепло',
      act: () async {
        await tester.drag(find.byType(Slider), const Offset(70, 0));
        await harness.settleReal(tester);
        final photoId = harness.session!.document.assets.first.id;
        expect(
          harness.session!.document.adjustmentFor(photoId).temperature,
          isNot(0),
        );
      },
    );

    await _drain(tester, harness);
  });

  testWidgets('«Стиль»: look ставится и откатывается', (tester) async {
    usePhoneSurface(tester);
    final harness = await editorWith(tester, photos: 2);

    await expectToolChangesDocument(
      tester,
      harness,
      tool: 'Стиль',
      act: () async {
        await tester.tap(find.text('Плёнка'));
        await harness.settleReal(tester);
        final photoId = harness.session!.document.assets.first.id;
        expect(
          harness.session!.document.adjustmentFor(photoId).look?.id,
          'film',
        );
      },
    );

    await _drain(tester, harness);
  });

  testWidgets('«Повернуть»: четверть оборота и откат', (tester) async {
    usePhoneSurface(tester);
    final harness = await editorWith(tester);

    await expectToolChangesDocument(
      tester,
      harness,
      tool: 'Повернуть',
      act: () async {
        await tester.tap(find.text('Повернуть на 90°'));
        await harness.settleReal(tester);
        expect(
          harness.session!.document.slotById('sheet_1', 'main')!.rotation,
          QuarterTurn.cw90,
        );
      },
    );

    await _drain(tester, harness);
  });

  testWidgets('«Заменить»: другое фото проекта и откат', (tester) async {
    usePhoneSurface(tester);
    final harness = await editorWith(tester, photos: 2);
    final handle = tester.ensureSemantics();

    await expectToolChangesDocument(
      tester,
      harness,
      tool: 'Заменить',
      act: () async {
        await tester.tap(find.bySemanticsLabel('Фото 2'));
        await harness.settleReal(tester);
        final slot = harness.session!.document.slotById('sheet_1', 'main')!;
        expect(slot.photoId, harness.session!.document.assets[1].id);
      },
    );

    handle.dispose();
    await _drain(tester, harness);
  });

  testWidgets('«Обменять»: два кадра меняются местами и откатываются', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final harness = await editorWith(tester, photos: 4, quad: true);

    final first = harness.session!.document.slotById('sheet_1', 'tl')!.photoId;
    final second = harness.session!.document.slotById('sheet_1', 'tr')!.photoId;

    await expectToolChangesDocument(
      tester,
      harness,
      tool: 'Обменять',
      act: () async {
        await _tapSheetCorner(tester, 0.25, 0.25);
        await harness.settleReal(tester);
        await _tapSheetCorner(tester, 0.75, 0.25);
        await harness.settleReal(tester);
        final spread = harness.session!.document.spreadById('sheet_1')!;
        expect(spread.slotById('tl')!.photoId, second);
        expect(spread.slotById('tr')!.photoId, first);
      },
    );

    await _drain(tester, harness);
  });

  testWidgets('«Заменить» сохраняет кадрирование и поворот слота', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final semantics = tester.ensureSemantics();
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
    controller.execute(
      SetSlotOrientation.turn(
        spreadId: 'sheet_1',
        slotId: 'tl',
        rotation: QuarterTurn.cw90,
        flipH: true,
      ),
    );
    controller.execute(
      const SetCrop(
        spreadId: 'sheet_1',
        slotId: 'tl',
        crop: Crop(x: 0.1, y: 0.2, w: 0.6, h: 0.7),
        zoom: 1.5,
        anchor: NormalizedPoint(0.3, 0.7),
      ),
    );
    await harness.settleReal(tester);
    final before = harness.session!.document.slotById('sheet_1', 'tl')!;

    await tester.ensureVisible(find.text('Заменить'));
    await tester.tap(find.text('Заменить'));
    await harness.settleReal(tester);
    await tester.tap(find.bySemanticsLabel('Фото 2'));
    await harness.settleReal(tester);

    final after = harness.session!.document.slotById('sheet_1', 'tl')!;
    expect(after.photoId, isNot(before.photoId), reason: 'фото другое');
    expect(
      after.crop,
      before.crop,
      reason: 'кадрирование переезжает вместе со слотом',
    );
    expect(after.zoom, before.zoom);
    expect(after.anchor, before.anchor);
    expect(after.rotation, QuarterTurn.cw90);
    expect(after.flipH, isTrue);

    semantics.dispose();
    await _drain(tester, harness);
  });

  testWidgets('«Фон»: цвет листа меняется и откатывается', (tester) async {
    usePhoneSurface(tester);
    final harness = await editorWith(tester);

    await expectToolChangesDocument(
      tester,
      harness,
      tool: 'Фон',
      act: () async {
        await tester.tap(find.text('Мята'));
        await harness.settleReal(tester);
        expect(
          harness.session!.document.spreadById('sheet_1')!.background.value,
          '#C4DAD6',
        );
      },
    );

    await _drain(tester, harness);
  });
}

Future<void> _tapSheetCorner(WidgetTester tester, double x, double y) async {
  final scene = tester.getRect(find.byType(SheetScene));
  await tester.tapAt(scene.topLeft + Offset(scene.width * x, scene.height * y));
  await tester.pump();
}

Future<void> _drain(WidgetTester tester, DesignHarness harness) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 3));
  await harness.settleReal(tester, frames: 4);
  await harness.disposeForTest(tester);
}
