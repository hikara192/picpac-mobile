import 'dart:io';

import 'package:design_core/design_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/features/_shared/application/design_session.dart';

import '../features/support/design_fixtures.dart';
import '../features/support/design_harness.dart';

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

  testWidgets('project.png — проект с 10 фото', (tester) async {
    useIPhoneViewport(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 10);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester);

    expect(harness.session!.document.photoCount, 10);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../docs/screenshots/project.png'),
    );
    await _drain(tester, harness);
  });

  testWidgets('editor.png — кадрирование листа', (tester) async {
    useIPhoneViewport(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: 3);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester, location: '/editor/dsg_1');

    harness.container
        .read(designSessionProvider('dsg_1').notifier)
        .selectSlot('sheet_1', 'main');
    await harness.settleReal(tester);
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../docs/screenshots/editor.png'),
    );
    await _drain(tester, harness);
  });

  testWidgets('preflight.png — проверка с замечаниями', (tester) async {
    useIPhoneViewport(tester);
    final harness = await DesignHarness.forWidgetTest(tester);
    final seeded = await harness.seedPhotosForTest(tester, count: 1);
    final small = seeded.copyWith(
      assets: <PhotoAsset>[
        for (final asset in seeded.assets)
          asset.copyWith(widthPx: 800, heightPx: 600),
      ],
    );
    harness.stubBasics(design: designDto(document: small));
    await harness.pump(tester, location: '/preflight/dsg_1');

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../docs/screenshots/preflight.png'),
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
