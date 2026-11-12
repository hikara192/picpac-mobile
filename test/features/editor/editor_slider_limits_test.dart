import 'package:design_core/design_core.dart' hide TextAlign;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/features/editor/presentation/widgets/editor_tool_panels.dart';
import 'package:riverpod/misc.dart' show Override;

import '../support/design_fixtures.dart';
import '../support/design_harness.dart';

void main() {
  setUpAll(registerDesignFallbacks);

  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<DesignHarness> openTool(
    WidgetTester tester,
    String tool, {
    List<Override> extraOverrides = const <Override>[],
  }) async {
    final harness = await DesignHarness.forWidgetTest(
      tester,
      extraOverrides: extraOverrides,
    );
    final document = await harness.seedPhotosForTest(tester, count: 1);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester, location: '/editor/dsg_1');
    await tester.tap(find.text(tool));
    await harness.settleReal(tester);
    return harness;
  }

  Slider sliderOf(WidgetTester tester) =>
      tester.widget<Slider>(find.byType(Slider));

  testWidgets('«Свет»: диапазон и шаг — из AdjustmentLimits.exposure', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final harness = await openTool(tester, 'Свет');

    final slider = sliderOf(tester);
    expect(slider.min, AdjustmentLimits.exposure.uiLower);
    expect(slider.max, AdjustmentLimits.exposure.uiUpper);
    expect(
      slider.divisions,
      ((AdjustmentLimits.exposure.uiUpper - AdjustmentLimits.exposure.uiLower) /
              AdjustmentLimits.exposure.step)
          .round(),
      reason: 'шаг ползунка — step ядра (±1 EV по 0.05)',
    );

    await _drain(tester, harness);
  });

  testWidgets('«Тепло»: диапазон из AdjustmentLimits.temperature', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final harness = await openTool(tester, 'Тепло');

    final slider = sliderOf(tester);
    expect(slider.min, AdjustmentLimits.temperature.uiLower);
    expect(slider.max, AdjustmentLimits.temperature.uiUpper);
    expect(
      slider.divisions,
      ((AdjustmentLimits.temperature.uiUpper -
                  AdjustmentLimits.temperature.uiLower) /
              AdjustmentLimits.temperature.step)
          .round(),
    );

    await _drain(tester, harness);
  });

  testWidgets('изменение лимита в ядре меняет диапазон ползунка', (
    tester,
  ) async {
    usePhoneSurface(tester);
    const narrowed = AdjustmentLimit(
      id: 'exposure',
      field: PhotoAdjustmentField.exposure,
      labelKey: 'editorToolLight',
      min: -2,
      max: 2,
      step: 0.1,
      uiMin: -0.4,
      uiMax: 0.4,
    );
    final harness = await openTool(
      tester,
      'Свет',
      extraOverrides: <Override>[
        adjustmentLimitLookupProvider.overrideWithValue(
          (PhotoAdjustmentField field) => field == PhotoAdjustmentField.exposure
              ? narrowed
              : AdjustmentLimits.of(field),
        ),
      ],
    );

    final slider = sliderOf(tester);
    expect(slider.min, -0.4, reason: 'литерал -1 здесь был бы багом');
    expect(slider.max, 0.4);
    expect(slider.divisions, 8);

    await _drain(tester, harness);
  });
}

Future<void> _drain(WidgetTester tester, DesignHarness harness) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 3));
  await harness.settleReal(tester, frames: 4);
  await harness.disposeForTest(tester);
}
