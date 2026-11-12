import 'package:design_core/design_core.dart' hide TextAlign;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/app/theme/tokens.dart';

import '../support/design_fixtures.dart';
import '../support/design_harness.dart';

void main() {
  setUpAll(registerDesignFallbacks);

  void useSmallScaledViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  testWidgets('проект: 320 pt и textScaler 1.3 без переполнений', (
    tester,
  ) async {
    useSmallScaledViewport(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 3);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester);

    expect(tester.takeException(), isNull);
    final button = find.widgetWithText(FilledButton, 'Проверить');
    expect(
      tester.getSize(button).height,
      greaterThanOrEqualTo(kMinTouchTarget),
    );

    await _drain(tester, harness);
  });

  testWidgets('редактор: 320 pt и textScaler 1.3 без переполнений', (
    tester,
  ) async {
    useSmallScaledViewport(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 2);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester, location: '/editor/dsg_1');

    expect(tester.takeException(), isNull);
    expect(find.text('Лист 1 из 2'), findsOneWidget);

    await _drain(tester, harness);
  });

  testWidgets('preflight: 320 pt и textScaler 1.3 без переполнений', (
    tester,
  ) async {
    useSmallScaledViewport(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 1);
    final small = document.copyWith(
      assets: <PhotoAsset>[
        for (final asset in document.assets)
          asset.copyWith(widthPx: 800, heightPx: 600),
      ],
    );
    harness.stubBasics(design: designDto(document: small));
    await harness.pump(tester, location: '/preflight/dsg_1');

    expect(tester.takeException(), isNull);
    expect(find.textContaining('800×600'), findsOneWidget);

    await _drain(tester, harness);
  });
}

Future<void> _drain(WidgetTester tester, DesignHarness harness) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 3));
  await harness.settleReal(tester, frames: 4);
  await harness.disposeForTest(tester);
}
