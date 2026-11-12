import 'package:design_core/design_core.dart';
import 'package:flutter/material.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/features/_shared/application/design_session.dart';
import 'package:picpac_mobile/features/_shared/application/frame_analyzer.dart';

import '../support/design_fixtures.dart';
import '../support/design_harness.dart';

void main() {
  setUpAll(registerDesignFallbacks);

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('«Улучшить все» идемпотентно и откатывается одним undo', (
    tester,
  ) async {
    useTallSurface(tester);
    final analyzer = _FakeFrameAnalyzer();
    final harness = await DesignHarness.forWidgetTest(
      tester,
      extraOverrides: <Override>[
        frameAnalyzerProvider.overrideWithValue(analyzer),
      ],
    );
    final document = await harness.seedPhotosForTest(tester, count: 3);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester);

    final notifier = harness.container.read(
      designSessionProvider('dsg_1').notifier,
    );

    await tester.tap(find.text('Улучшить все'));
    await _waitFor(
      tester,
      harness,
      () => harness.session!.document.photoAdjustments.length == 3,
    );

    expect(analyzer.calls, 3, reason: 'по одному прокси на фото');
    expect(find.text('Улучшено 3 фото'), findsOneWidget);
    expect(find.text('Вернуть'), findsOneWidget);

    final revision = harness.session!.document.revision;
    final adjustment = harness.session!.document.adjustmentFor(
      harness.session!.document.assets.first.id,
    );
    expect(adjustment.isNeutral, isFalse, reason: 'ядро предложило тон-правку');

    await tester.tap(find.text('Улучшить все'));
    await _waitFor(
      tester,
      harness,
      () => find.text('Всё уже улучшено').evaluate().isNotEmpty,
    );
    expect(harness.session!.document.revision, revision);
    expect(harness.session!.document.photoAdjustments.length, 3);

    notifier.undo();
    await harness.settleReal(tester);
    expect(harness.session!.document.photoAdjustments, isEmpty);

    await _drain(tester, harness);
  });

  testWidgets('«Вернуть как было» сбрасывает правки одним undo', (
    tester,
  ) async {
    useTallSurface(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 2);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester);

    final notifier = harness.container.read(
      designSessionProvider('dsg_1').notifier,
    );
    final photoId = harness.session!.document.assets.first.id;
    notifier.execute(
      SetPhotoAdjustment(
        photoId: photoId,
        field: PhotoAdjustmentField.temperature,
        value: 30,
      ),
    );
    notifier.execute(
      SetCrop(spreadId: 'sheet_1', slotId: 'main', crop: Crop.full, zoom: 2),
    );
    await harness.settleReal(tester);
    expect(harness.session!.document.photoAdjustments, isNotEmpty);

    await tester.tap(find.text('Вернуть как было'));
    await harness.settleReal(tester);

    final after = harness.session!.document;
    expect(after.photoAdjustments, isEmpty);
    expect(after.slotById('sheet_1', 'main')!.zoom, 1);

    notifier.undo();
    await harness.settleReal(tester);
    expect(
      harness.session!.document.photoAdjustments,
      isNotEmpty,
      reason: 'сброс — один шаг undo',
    );

    await _drain(tester, harness);
  });

  testWidgets('предложение раскладки: «4 листа вместо 10»', (tester) async {
    useTallSurface(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 10);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester);

    expect(harness.session!.spreads.length, 10);
    expect(find.text('4 листа вместо 10'), findsOneWidget);

    await tester.tap(find.text('Так лучше'));
    await harness.settleReal(tester);
    expect(harness.session!.spreads.length, 4);
    expect(
      find.text('4 листа вместо 10'),
      findsNothing,
      reason: 'применённая раскладка больше не предлагается',
    );

    harness.container.read(designSessionProvider('dsg_1').notifier).undo();
    await harness.settleReal(tester);
    expect(harness.session!.spreads.length, 10);

    await _drain(tester, harness);
  });
}

final class _FakeFrameAnalyzer implements FrameAnalyzer {
  int calls = 0;

  @override
  Future<FrameStats?> analyze(String filePath) async {
    calls++;
    final histogram = List<int>.filled(256, 0);
    histogram[40] = 400;
    histogram[200] = 600;
    return FrameStats(
      lumaHistogram: histogram,
      meanR: 0.24,
      meanG: 0.22,
      meanB: 0.32,
      meanChroma: 0.25,
      highlightFraction: 0,
      sampleCount: 1000,
    );
  }
}

Future<void> _waitFor(
  WidgetTester tester,
  DesignHarness harness,
  bool Function() done,
) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (done()) return;
  }
}

Future<void> _drain(WidgetTester tester, DesignHarness harness) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump(const Duration(seconds: 3));
  await harness.settleReal(tester, frames: 8);
  await harness.disposeForTest(tester);
}
