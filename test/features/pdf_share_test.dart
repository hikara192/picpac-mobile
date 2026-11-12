import 'dart:typed_data';

import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/core/analytics.dart';
import 'package:picpac_mobile/core/export/pdf_share.dart';
import 'package:picpac_mobile/features/_shared/application/pdf_export_controller.dart';
import 'package:riverpod/misc.dart' show Override;

import 'support/design_fixtures.dart';
import 'support/design_harness.dart';

final class FakePdfShare implements PdfSharePort {
  final List<Uint8List> shared = <Uint8List>[];
  final List<String> names = <String>[];
  ShareOutcome outcome = ShareOutcome.shared;
  Object? error;

  @override
  Future<ShareOutcome> sharePdf({
    required Uint8List bytes,
    required String fileName,
    String? subject,
  }) async {
    final failure = error;
    if (failure != null) throw failure;
    shared.add(bytes);
    names.add(fileName);
    return outcome;
  }
}

void main() {
  setUpAll(registerDesignFallbacks);

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() done, {
    int attempts = 600,
  }) async {
    for (var index = 0; index < attempts && !done(); index++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 40));
    }
  }

  Future<DesignHarness> harnessWith(
    WidgetTester tester,
    FakePdfShare share,
  ) async {
    final harness = await DesignHarness.forWidgetTest(
      tester,
      format: printFormat(widthMm: 25.4, heightMm: 25.4),
      extraOverrides: <Override>[pdfShareProvider.overrideWithValue(share)],
    );
    final document = await harness.seedPhotosForTest(tester, count: 10);
    harness.stubBasics(design: designDto(document: document));
    return harness;
  }

  DesignDocument emptySlotDocument() => DesignDocument(
    product: const DocumentProduct(id: 'photo_print', formatId: '10x15'),
    spreads: <Spread>[
      Spread(
        id: 'sheet_1',
        templateId: 'single_10x15',
        background: SpreadBackground.color('#FAF5ED'),
        slots: const <Slot>[Slot(id: 'main')],
      ),
    ],
    spreadsCount: 1,
  );

  testWidgets('10 листов → непустой PDF в системном «Поделиться»', (
    tester,
  ) async {
    useTallSurface(tester);
    final share = FakePdfShare();
    final harness = await harnessWith(tester, share);
    await harness.pump(tester, location: '/preflight/dsg_1');

    final button = find.byKey(const Key('preflight-share-pdf'));
    expect(button, findsOneWidget);
    expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);

    await tester.tap(button);
    await pumpUntil(tester, () => share.shared.isNotEmpty);

    expect(share.shared, hasLength(1));
    final pdf = share.shared.single;
    expect(String.fromCharCodes(pdf.sublist(0, 5)), '%PDF-');
    expect(pdf.length, greaterThan(10 * 1024), reason: 'ten pages are inside');
    expect(share.names.single, endsWith('.pdf'));
    expect(harness.analytics.has(AnalyticsEvent.pdfExported), isTrue);
    expect(find.text('Поделиться PDF'), findsOneWidget);

    await harness.disposeForTest(tester);
  });

  testWidgets('блокирующие замечания не дают поделиться PDF', (tester) async {
    useTallSurface(tester);
    final share = FakePdfShare();
    final harness = await DesignHarness.forWidgetTest(
      tester,
      format: printFormat(widthMm: 25.4, heightMm: 25.4),
      extraOverrides: <Override>[pdfShareProvider.overrideWithValue(share)],
    );
    harness.stubBasics(design: designDto(document: emptySlotDocument()));
    await harness.pump(tester, location: '/preflight/dsg_1');

    expect(find.text('Добавьте фото'), findsOneWidget);
    final button = find.byKey(const Key('preflight-share-pdf'));
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    expect(find.text('Поделиться PDF'), findsOneWidget);

    await harness.disposeForTest(tester);
  });

  testWidgets('после подтверждения замечаний PDF снова доступен', (
    tester,
  ) async {
    useTallSurface(tester);
    final share = FakePdfShare();
    final harness = await DesignHarness.forWidgetTest(
      tester,
      format: printFormat(widthMm: 25.4, heightMm: 25.4),
      extraOverrides: <Override>[pdfShareProvider.overrideWithValue(share)],
    );
    harness.stubBasics(design: designDto(document: emptySlotDocument()));
    await harness.pump(tester, location: '/preflight/dsg_1');

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Продолжить всё равно'),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.widgetWithText(FilledButton, 'Продолжить'));
    await harness.settleReal(tester, frames: 8);

    final button = find.byKey(const Key('preflight-share-pdf'));
    expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);

    await tester.tap(button);
    await pumpUntil(tester, () => share.shared.isNotEmpty);
    expect(share.shared, hasLength(1));
    expect(String.fromCharCodes(share.shared.single.sublist(0, 5)), '%PDF-');

    await harness.disposeForTest(tester);
  });
}
