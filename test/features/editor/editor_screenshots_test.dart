import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/features/_shared/application/design_session.dart';

import '../support/design_fixtures.dart';
import '../support/design_harness.dart';

void main() {
  setUpAll(() async {
    registerDesignFallbacks();
    final loader = FontLoader('FuturaPT')
      ..addFont(rootBundle.load('assets/fonts/futura-pt-400.ttf'))
      ..addFont(rootBundle.load('assets/fonts/futura-pt-500.ttf'));
    await loader.load();
    await _loadMaterialIcons();
  });

  void useIPhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('editor-tools.png — лента из восьми инструментов', (
    tester,
  ) async {
    useIPhoneViewport(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 3);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester, location: '/editor/dsg_1');

    harness.container
        .read(designSessionProvider('dsg_1').notifier)
        .selectSlot('sheet_1', 'main');
    await harness.settleReal(tester);
    await tester.tap(find.text('Кадр'));
    await harness.waitForSync(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../docs/screenshots/editor-tools.png'),
    );
    await _drain(tester, harness);
  });

  testWidgets('editor-styles.png — стиль применён ко всем фото', (
    tester,
  ) async {
    useIPhoneViewport(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 3);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester, location: '/editor/dsg_1');

    await tester.tap(find.text('Стиль'));
    await harness.settleReal(tester);
    await tester.tap(find.text('Плёнка'));
    await harness.waitForSync(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../docs/screenshots/editor-styles.png'),
    );
    await _drain(tester, harness);
  });

  testWidgets('create-enhance.png — «Улучшить все» на экране проекта', (
    tester,
  ) async {
    useIPhoneViewport(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 10);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester);
    await harness.waitForSync(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../docs/screenshots/create-enhance.png'),
    );
    await _drain(tester, harness);
  });
}

Future<void> _loadMaterialIcons() async {
  final loader = FontLoader('MaterialIcons');
  for (final path in const <String>[
    'fonts/MaterialIcons-Regular.otf',
    'packages/flutter/MaterialIcons-Regular.otf',
  ]) {
    try {
      loader.addFont(rootBundle.load(path));
      await loader.load();
      return;
    } on Object {
      continue;
    }
  }
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final file = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!file.existsSync()) return;
  final fallback = FontLoader('MaterialIcons')
    ..addFont(
      Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
    );
  await fallback.load();
}

Future<void> _drain(WidgetTester tester, DesignHarness harness) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 3));
  await harness.settleReal(tester, frames: 4);
  await harness.disposeForTest(tester);
}
