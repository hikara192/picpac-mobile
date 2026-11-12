import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:picpac_mobile/core/analytics.dart';
import 'package:picpac_mobile/features/editor/presentation/editor_page.dart';

import '../support/design_fixtures.dart';
import '../support/design_harness.dart';

void main() {
  setUpAll(registerDesignFallbacks);

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('пустой слот блокирует «В корзину»', (tester) async {
    useTallSurface(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    harness.stubBasics();
    await harness.pump(tester, location: '/preflight/dsg_1');

    expect(find.text('Добавьте фото'), findsOneWidget);
    expect(find.textContaining('Пока есть блокирующие'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'В корзину'),
    );
    expect(button.onPressed, isNull);

    await _drain(tester, harness);
  });

  testWidgets('LOW_DPI называет конкретные пиксели и нужный размер', (
    tester,
  ) async {
    useTallSurface(tester);
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

    expect(find.textContaining('800×600'), findsOneWidget);
    expect(find.textContaining('102 × 152 мм'), findsOneWidget);
    expect(find.textContaining('1205×1795'), findsOneWidget);
    expect(find.textContaining('станет мыльным'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'В корзину'),
    );
    expect(button.onPressed, isNotNull);

    await _drain(tester, harness);
  });

  testWidgets('подтверждение разблокирует заказ и логируется', (tester) async {
    useTallSurface(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    harness.stubBasics();
    await harness.pump(tester, location: '/preflight/dsg_1');

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Продолжить всё равно'),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Продолжить с замечаниями?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Продолжить'));
    await harness.settleReal(tester);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'В корзину'),
    );
    expect(button.onPressed, isNotNull);
    expect(harness.analytics.has(AnalyticsEvent.preflightOverridden), isTrue);
    final payload = harness.analytics.payloads.last;
    expect(payload['codes'], contains(PreflightCode.emptySlot.wire));

    await _drain(tester, harness);
  });

  testWidgets('тап по проблеме открывает слот в редакторе', (tester) async {
    useTallSurface(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    harness.stubBasics();
    await harness.pump(tester, location: '/preflight/dsg_1');

    await tester.tap(find.text('Добавьте фото').first);
    await harness.settleReal(tester);

    expect(find.byType(EditorPage), findsOneWidget);
    expect(harness.session!.selectedSpreadId, 'sheet_1');
    expect(harness.session!.selectedSlotId, 'main');

    await _drain(tester, harness);
  });

  testWidgets('расхождение с сервером показывается, а не маскируется', (
    tester,
  ) async {
    useTallSurface(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    harness.stubBasics();
    when(() => harness.api.preflight(any(), revision: any(named: 'revision')))
        .thenAnswer(
          (_) async => Ok<PreflightDto>(
            const PreflightDto(
              revision: 1,
              canOrder: false,
              issues: <PreflightIssue>[
                PreflightIssue(
                  code: PreflightCode.lowDpi,
                  severity: PreflightSeverity.warning,
                  targetId: 'main',
                  messageKey: PreflightMessageKeys.lowDpi,
                  args: <String, Object?>{
                    'photoPx': '640×480',
                    'requiredPx': '1205×1795',
                    'slotWidthMm': 102.0,
                    'slotHeightMm': 152.0,
                  },
                  spreadId: 'sheet_1',
                  slotId: 'main',
                ),
              ],
            ),
          ),
        );
    await harness.pump(tester, location: '/preflight/dsg_1');

    expect(find.textContaining('Показываем проверку сервера'), findsOneWidget);
    expect(find.textContaining('640×480'), findsOneWidget);

    await _drain(tester, harness);
  });

  testWidgets('«В корзину» передаёт количество листов, а не 1', (tester) async {
    useTallSurface(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 10);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester, location: '/preflight/dsg_1');

    await tester.tap(find.widgetWithText(FilledButton, 'В корзину'));
    await harness.settleReal(tester);

    final captured = verify(() => harness.api.addCartItem(captureAny()))
        .captured;
    final request = captured.single as AddCartItemRequest;
    expect(request.designId, 'dsg_1');
    expect(request.quantity, 10);
    expect(request.quantity, document.spreads.length);

    await _drain(tester, harness);
  });

  testWidgets('«В корзину» добавляет проект и ведёт в корзину', (tester) async {
    useTallSurface(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 1);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester, location: '/preflight/dsg_1');

    await tester.tap(find.widgetWithText(FilledButton, 'В корзину'));
    await harness.settleReal(tester);

    verify(() => harness.api.addCartItem(any())).called(1);
    expect(find.text('Корзина'), findsWidgets);

    await _drain(tester, harness);
  });
}

Future<void> _drain(WidgetTester tester, DesignHarness harness) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 3));
  await harness.settleReal(tester, frames: 4);
  await harness.disposeForTest(tester);
}
