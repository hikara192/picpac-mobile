import 'package:design_core/design_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/app/router.dart';
import 'package:picpac_mobile/features/_shared/application/design_session.dart';

import '../support/design_fixtures.dart';
import '../support/design_harness.dart';

void main() {
  setUpAll(registerDesignFallbacks);

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> rotate(WidgetTester tester, DesignHarness harness) async {
    final result = harness.container
        .read(designSessionProvider('dsg_1').notifier)
        .execute(
          const SetSlotOrientation(
            spreadId: 'sheet_1',
            slotId: 'main',
            rotation: 90,
            flipH: false,
          ),
        );
    expect(result, isA<CommandOk>());
    await harness.settleReal(tester, frames: 8);
  }

  testWidgets('портретное фото повернули — preflight видит 234 dpi и пиксели', (
    tester,
  ) async {
    useTallSurface(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(
      tester,
      count: 1,
      width: 1400,
      height: 2100,
    );
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester, location: AppRoutes.createFor('dsg_1'));

    expect(
      harness.session!.document.spreads.single.slots.single.rotation,
      QuarterTurn.none,
    );
    await rotate(tester, harness);
    expect(
      harness.session!.document.spreads.single.slots.single.rotation,
      QuarterTurn.cw90,
    );

    harness.container.read(routerProvider).go('/preflight/dsg_1');
    await harness.settleReal(tester, frames: 24);

    expect(find.textContaining('1400×2100'), findsOneWidget);
    expect(find.textContaining('102 × 152 мм'), findsOneWidget);
    expect(find.textContaining('1205×1795'), findsOneWidget);
    expect(find.textContaining('станет мыльным'), findsOneWidget);

    await _drain(tester, harness);
  });

  testWidgets('ландшафтное фото: мыльное до поворота, чистое после', (
    tester,
  ) async {
    useTallSurface(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(
      tester,
      count: 1,
      width: 2100,
      height: 1400,
    );
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester, location: AppRoutes.createFor('dsg_1'));

    harness.container.read(routerProvider).go('/preflight/dsg_1');
    await harness.settleReal(tester, frames: 24);
    expect(find.textContaining('станет мыльным'), findsOneWidget);

    harness.container.read(routerProvider).go(AppRoutes.createFor('dsg_1'));
    await harness.settleReal(tester, frames: 8);
    await rotate(tester, harness);
    harness.container.read(routerProvider).go('/preflight/dsg_1');
    await harness.settleReal(tester, frames: 24);

    expect(find.text('Можно печатать'), findsOneWidget);
    expect(find.textContaining('станет мыльным'), findsNothing);

    await _drain(tester, harness);
  });
}

Future<void> _drain(WidgetTester tester, DesignHarness harness) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 3));
  await harness.settleReal(tester, frames: 4);
  await harness.disposeForTest(tester);
}
