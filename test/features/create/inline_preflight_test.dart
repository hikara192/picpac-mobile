import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:picpac_mobile/app/router.dart';

import '../support/design_fixtures.dart';
import '../support/design_harness.dart';

void main() {
  setUpAll(registerDesignFallbacks);

  void stubReport(DesignHarness harness, List<PreflightIssue> issues) {
    when(() => harness.api.preflight(any(), revision: any(named: 'revision')))
        .thenAnswer(
          (_) async => Ok<PreflightDto>(preflightDto(PreflightReport(issues))),
        );
  }

  PreflightIssue issue(PreflightSeverity severity, String slot) =>
      PreflightIssue(
        code: PreflightCode.lowDpi,
        severity: severity,
        targetId: slot,
        messageKey: 'preflight.lowDpi',
        spreadId: 'sheet_1',
        slotId: slot,
        args: const <String, Object?>{
          'photoPx': '800×600',
          'requiredPx': '1181×1772',
          'slotWidthMm': 102,
          'slotHeightMm': 152,
        },
      );

  FilledButton cta(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(const Key('create-order-cta')));

  testWidgets('чистый проект: info, кнопка активна и ведёт в корзину', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 1);
    harness.stubBasics(design: designDto(document: document));
    stubReport(harness, const <PreflightIssue>[]);
    await harness.pump(tester);
    await harness.settleReal(tester, frames: 6);

    expect(find.byIcon(Icons.info_outline), findsWidgets);
    expect(cta(tester).onPressed, isNotNull);
    expect(find.text('Замечаний нет'), findsNothing, reason: 'текст в tooltip');

    await tester.tap(find.byKey(const Key('create-order-cta')));
    await harness.settleReal(tester, frames: 20);

    expect(harness.container.read(routerProvider).state.uri.path, '/cart');
    await harness.disposeForTest(tester);
  });

  testWidgets('2 warning: счётчик 2 и кнопка работает', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 1);
    harness.stubBasics(design: designDto(document: document));
    stubReport(harness, <PreflightIssue>[
      issue(PreflightSeverity.warning, 'main'),
      issue(PreflightSeverity.warning, 'top'),
    ]);
    await harness.pump(tester);
    await harness.settleReal(tester, frames: 6);

    expect(find.byIcon(Icons.warning_amber_outlined), findsWidgets);
    expect(find.text('2'), findsOneWidget);
    expect(cta(tester).onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('create-preflight-status')));
    await harness.settleReal(tester, frames: 6);
    expect(find.text('Проверка макета'), findsOneWidget);

    await harness.disposeForTest(tester);
  });

  testWidgets('error: кнопка не оформляет, а открывает шторку', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 1);
    harness.stubBasics(design: designDto(document: document));
    stubReport(harness, <PreflightIssue>[
      issue(PreflightSeverity.error, 'main'),
    ]);
    await harness.pump(tester);
    await harness.settleReal(tester, frames: 6);

    expect(find.byIcon(Icons.error_outline), findsWidgets);

    await tester.tap(find.byKey(const Key('create-order-cta')));
    await harness.settleReal(tester, frames: 10);

    expect(find.text('Проверка макета'), findsOneWidget);
    expect(find.byKey(const Key('preflight-ack-and-order')), findsOneWidget);
    expect(
      harness.container.read(routerProvider).state.uri.path,
      '/create/dsg_1',
    );

    await harness.disposeForTest(tester);
  });
}
