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

  testWidgets('ровно восемь инструментов и ни одного «продвинутого»', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 2);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester, location: '/editor/dsg_1');

    for (final label in <String>[
      'Кадр',
      'Свет',
      'Тепло',
      'Стиль',
      'Повернуть',
      'Заменить',
      'Обменять',
      'Фон',
    ]) {
      expect(find.text(label), findsOneWidget, reason: 'инструмент «$label»');
    }

    for (final forbidden in <String>[
      'Кисть',
      'Слои',
      'Кривые',
      'Виньетка',
      'Зерно',
      'Маски',
      'HDR',
      'Стикеры',
      'Текст',
    ]) {
      expect(find.text(forbidden), findsNothing, reason: 'лишнее «$forbidden»');
    }
    expect(find.byIcon(Icons.brush), findsNothing);

    await _drain(tester, harness);
  });

  testWidgets('«Свет» меняет документ и откатывается одним undo', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 1);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester, location: '/editor/dsg_1');

    await tester.tap(find.text('Кадр'));
    await tester.pump();
    await tester.tap(find.text('Свет'));
    await harness.settleReal(tester);

    expect(find.byType(Slider), findsOneWidget);
    await tester.drag(find.byType(Slider), const Offset(90, 0));
    await harness.settleReal(tester);

    final photoId = harness.session!.document.assets.first.id;
    final exposure =
        harness.session!.document.photoAdjustments[photoId]?.exposure;
    expect(exposure, isNotNull);
    expect(exposure, isNot(0));

    harness.container.read(designSessionProvider('dsg_1').notifier).undo();
    await harness.settleReal(tester);
    expect(
      harness.session!.document.photoAdjustments[photoId],
      isNull,
      reason: 'один шаг undo возвращает значение до слайдера',
    );

    await _drain(tester, harness);
  });

  testWidgets('«Стиль» ставит look на все фото и снимается', (tester) async {
    usePhoneSurface(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 2);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester, location: '/editor/dsg_1');

    await tester.tap(find.text('Стиль'));
    await harness.settleReal(tester);
    await tester.tap(find.text('Плёнка'));
    await harness.settleReal(tester);

    final notifier = harness.container.read(
      designSessionProvider('dsg_1').notifier,
    );
    for (final asset in harness.session!.document.assets) {
      expect(
        harness.session!.document.adjustmentFor(asset.id).look?.id,
        'film',
        reason: 'стиль применяется ко всем фото проекта',
      );
    }

    await tester.tap(find.text('Как есть'));
    await harness.settleReal(tester);
    for (final asset in harness.session!.document.assets) {
      expect(harness.session!.document.adjustmentFor(asset.id).look, isNull);
    }

    notifier.undo();
    await harness.settleReal(tester);
    expect(
      harness.session!.document
          .adjustmentFor(harness.session!.document.assets.first.id)
          .look
          ?.id,
      'film',
      reason: 'снятие стиля — тоже один шаг undo',
    );

    await _drain(tester, harness);
  });

  testWidgets('«Повернуть» пишет четверть оборота и откатывается', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final harness = await DesignHarness.forWidgetTest(
      tester,
      format: printFormat(quadFirst: true),
    );
    final document = await harness.seedPhotosForTest(tester, count: 4);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester, location: '/editor/dsg_1');

    await _tapSheetCorner(tester, 0.25, 0.25);
    await harness.settleReal(tester);
    expect(harness.session!.selectedSlotId, 'tl');

    await tester.ensureVisible(find.text('Повернуть'));
    await tester.tap(find.text('Повернуть'));
    await harness.settleReal(tester);
    await tester.tap(find.text('Повернуть на 90°'));
    await harness.settleReal(tester);

    final rotated = harness.session!.document.slotById('sheet_1', 'tl')!;
    expect(rotated.rotation.degrees, 90);

    harness.container.read(designSessionProvider('dsg_1').notifier).undo();
    await harness.settleReal(tester);
    expect(
      harness.session!.document.slotById('sheet_1', 'tl')!.rotation.degrees,
      0,
    );

    await _drain(tester, harness);
  });

  testWidgets('«Обменять» меняет два фото одного листа', (tester) async {
    usePhoneSurface(tester);
    final harness = await DesignHarness.forWidgetTest(
      tester,
      format: printFormat(quadFirst: true),
    );
    final document = await harness.seedPhotosForTest(tester, count: 4);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester, location: '/editor/dsg_1');

    final before = harness.session!.document.spreadById('sheet_1')!;
    final first = before.slotById('tl')!.photoId;
    final second = before.slotById('tr')!.photoId;

    await _tapSheetCorner(tester, 0.25, 0.25);
    await harness.settleReal(tester);
    await tester.ensureVisible(find.text('Обменять'));
    await tester.tap(find.text('Обменять'));
    await harness.settleReal(tester);
    expect(find.textContaining('Поменяем с фото'), findsOneWidget);

    await _tapSheetCorner(tester, 0.75, 0.25);
    await harness.settleReal(tester);

    final after = harness.session!.document.spreadById('sheet_1')!;
    expect(after.slotById('tl')!.photoId, second);
    expect(after.slotById('tr')!.photoId, first);

    await _drain(tester, harness);
  });

  testWidgets('пустой слот ведёт в импорт', (tester) async {
    usePhoneSurface(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    harness.stubBasics();
    await harness.pump(tester, location: '/editor/dsg_1');

    expect(harness.session!.document.photoCount, 0);
    expect(find.text('Добавить фото'), findsWidgets);

    await tester.tap(find.text('Добавить фото').first);
    await harness.settleReal(tester);

    expect(
      harness.picker.calls,
      1,
      reason: 'тап в пустом слоте открывает пикер',
    );

    await _drain(tester, harness);
  });

  testWidgets('320 pt и шрифт 1.3 — панели не переполняются', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 1);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester, location: '/editor/dsg_1');

    for (final label in <String>[
      'Кадр',
      'Свет',
      'Тепло',
      'Стиль',
      'Повернуть',
      'Заменить',
      'Обменять',
      'Фон',
    ]) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'панель «$label»');
    }

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
