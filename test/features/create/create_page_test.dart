import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/features/_shared/application/design_session.dart';
import 'package:picpac_mobile/features/_shared/presentation/sheet_scene.dart';
import 'package:picpac_mobile/core/media/photo_picker.dart';
import 'package:picpac_mobile/features/create/presentation/widgets/photo_grid.dart';

import '../support/design_fixtures.dart';
import '../support/design_harness.dart';

void main() {
  setUpAll(registerDesignFallbacks);

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('сетка показывает 10 фото с номерами и превью листа', (
    tester,
  ) async {
    useTallSurface(tester);
    final handle = tester.ensureSemantics();
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 10);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester);

    expect(harness.session!.document.photoCount, 10);
    expect(find.byType(PhotoGrid), findsOneWidget);
    expect(find.byType(SheetScene), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Фото 1')), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('Фото 10')), findsWidgets);

    await _drain(tester, harness);
    handle.dispose();
  });

  testWidgets('плитка «+» импортирует выбор пикера в проект', (tester) async {
    useTallSurface(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    harness.stubBasics();
    final picked = <PickedFile>[];
    await tester.runAsync(() async {
      for (var i = 0; i < 2; i++) {
        final file = await writePng(
          harness.root,
          'picked_$i.png',
          width: 900,
          color: Color(0xFF204060 + i * 0x101010),
        );
        picked.add(pickedPng(file));
      }
    });
    harness.picker.queue(picked);
    await harness.pump(tester);

    expect(harness.session!.document.photoCount, 0);
    await tester.tap(find.byKey(const Key('photo-add-tile')));
    for (var i = 0; i < 12; i++) {
      await harness.settleReal(tester, frames: 6);
      if (harness.session?.document.photoCount == 2) break;
    }

    expect(harness.picker.calls, 1);
    expect(harness.session!.document.photoCount, 2);
    expect(find.bySemanticsLabel(RegExp('Фото 2')), findsWidgets);

    await _drain(tester, harness);
  });

  testWidgets('drag-and-drop меняет порядок фото', (tester) async {
    useTallSurface(tester);
    final handle = tester.ensureSemantics();
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 3);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester);

    final before = harness.session!.document.assets
        .map((asset) => asset.id)
        .toList();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey<String>('photo_tile_0'))),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey<String>('photo_tile_2'))),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await harness.settleReal(tester);

    final after = harness.session!.document.assets
        .map((asset) => asset.id)
        .toList();
    expect(after, <String>[before[1], before[2], before[0]]);

    await _drain(tester, harness);
    handle.dispose();
  });

  testWidgets('удаление фото спрашивает подтверждение и чистит слот', (
    tester,
  ) async {
    useTallSurface(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 2);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester);

    await tester.tap(find.byTooltip('Удалить фото 1'));
    await tester.pump();
    expect(find.text('Удалить фото?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await harness.settleReal(tester);

    final state = harness.session!;
    expect(state.document.photoCount, 1);
    expect(state.spreads.length, 1);
    expect(state.document.emptySlotCount, 0);

    await _drain(tester, harness);
  });

  testWidgets('превышение лимита формата объясняется текстом', (tester) async {
    useTallSurface(tester);
    final harness = await DesignHarness.forWidgetTest(
      tester,
      format: printFormat(minPhotos: 2, maxPhotos: 2, maxSpreads: 4),
    );
    final document = await harness.seedPhotosForTest(tester, count: 2);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester);

    expect(harness.session!.isAtPhotoLimit, isTrue);
    expect(
      find.text(
        'На лист помещается 2 фото. Уберите лишние, чтобы добавить новые.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('photo-add-tile')), findsNothing);

    await _drain(tester, harness);
  });

  testWidgets('офлайн показывает баннер и восстанавливает черновик', (
    tester,
  ) async {
    useTallSurface(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 2);
    await tester.runAsync(
      () => harness.drafts.saveNow(
        document,
        designId: 'dsg_1',
        productId: 'photo_print',
      ),
    );
    harness.stubBasics(designFailure: ApiFailure.networkUnavailable());
    await harness.pump(tester);
    await harness.settleReal(tester);

    expect(harness.session!.restoredFromCache, isTrue);
    expect(find.textContaining('Нет сети'), findsOneWidget);
    expect(find.byType(PhotoGrid), findsOneWidget);

    await _drain(tester, harness);
  });

  testWidgets('409 conflict_revision открывает диалог выбора версии', (
    tester,
  ) async {
    useTallSurface(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 1);
    harness.stubBasics(
      design: designDto(document: document),
      putFailure: const ApiFailure(
        code: ApiErrorCode.conflictRevision,
        message: 'newer revision on the server',
        statusCode: 409,
      ),
    );
    await harness.pump(tester);

    harness.container
        .read(designSessionProvider('dsg_1').notifier)
        .execute(
          const SetCrop(
            spreadId: 'sheet_1',
            slotId: 'main',
            crop: Crop.full,
            zoom: 2,
          ),
        );
    await tester.pump(const Duration(seconds: 3));
    await harness.settleReal(tester);

    expect(find.text('Проект изменён на другом устройстве'), findsWidgets);
    expect(find.text('Загрузить с сервера'), findsOneWidget);
    expect(find.text('Оставить мои правки'), findsOneWidget);

    await tester.tap(find.text('Оставить мои правки'));
    await harness.settleReal(tester);

    await _drain(tester, harness);
  });

  testWidgets('проект без фото: заказ заблокирован с пояснением', (
    tester,
  ) async {
    useTallSurface(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    harness.stubBasics();
    await harness.pump(tester);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('create-order-cta')),
    );
    expect(button.onPressed, isNull);
    expect(
      find.text('Добавьте хотя бы одно фото — тогда можно оформить заказ.'),
      findsOneWidget,
    );

    await _drain(tester, harness);
  });

  testWidgets('CTA «Оформить заказ» и статус проверки живут в проекте', (
    tester,
  ) async {
    useTallSurface(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 1);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester);

    expect(find.byKey(const Key('create-preflight-status')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Оформить заказ'), findsOneWidget);
    expect(find.text('Проверить'), findsNothing);

    await _drain(tester, harness);
  });
}

Future<void> _drain(WidgetTester tester, DesignHarness harness) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 3));
  await harness.settleReal(tester, frames: 4);
  await harness.disposeForTest(tester);
}
