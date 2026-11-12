import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/features/editor/presentation/widgets/editor_tool_bar.dart';

import '../features/support/design_fixtures.dart';
import '../features/support/design_harness.dart';

void main() {
  setUpAll(registerDesignFallbacks);

  Future<DesignHarness> pumpEditor(
    WidgetTester tester, {
    int photos = 2,
    bool reduceMotion = false,
  }) async {
    if (reduceMotion) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }
    final harness = await DesignHarness.forWidgetTest(tester);
    final document = await harness.seedPhotosForTest(tester, count: photos);
    harness.stubBasics(design: designDto(document: document));
    await harness.pump(tester, location: '/editor/dsg_1');
    return harness;
  }

  Future<void> drain(WidgetTester tester, DesignHarness harness) async {
    await tester.pump(const Duration(milliseconds: 300));
    await harness.settleReal(tester, frames: 4);
    await harness.disposeForTest(tester);
  }

  testWidgets('макет разворота — изображение с номером листа', (tester) async {
    final handle = tester.ensureSemantics();
    final harness = await pumpEditor(tester);

    final scene = tester.getSemantics(
      find.bySemanticsLabel('Макет разворота 1 из 2'),
    );
    expect(scene.flagsCollection.isImage, isTrue);

    handle.dispose();
    await drain(tester, harness);
  });

  testWidgets('слайдер «Свет» объявляет название и значение', (tester) async {
    final handle = tester.ensureSemantics();
    final harness = await pumpEditor(tester);

    await tester.tap(find.byKey(const ValueKey<String>('editor_tool_light')));
    await harness.settleReal(tester);

    SemanticsNode? slider;
    tester.getSemantics(find.byType(Slider)).visitChildren((node) {
      if (node.flagsCollection.isSlider) slider = node;
      return slider == null;
    });
    expect(slider, isNotNull);
    expect(slider!.value, startsWith('Свет, '));

    handle.dispose();
    await drain(tester, harness);
  });

  testWidgets('ручки кропа имеют текстовое имя и действие увеличения', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final harness = await pumpEditor(tester);

    await tester.tap(find.byKey(const ValueKey<String>('editor_tool_frame')));
    await harness.settleReal(tester);

    final handleNode = tester.getSemantics(
      find.bySemanticsLabel('Изменить кадр, угол левый верхний'),
    );
    expect(handleNode.flagsCollection.isButton, isFalse);
    expect(
      handleNode.getSemanticsData().hasAction(SemanticsAction.increase),
      isTrue,
    );

    handle.dispose();
    await drain(tester, harness);
  });

  testWidgets('лента инструментов обходится в порядке чтения', (tester) async {
    final harness = await pumpEditor(tester);

    final group = tester.widget<FocusTraversalGroup>(
      find
          .ancestor(
            of: find.byType(EditorToolBar),
            matching: find.byType(FocusTraversalGroup),
          )
          .first,
    );
    expect(group.policy, isA<ReadingOrderTraversalPolicy>());

    await drain(tester, harness);
  });

  testWidgets('reduced motion: панель открывается без перехода', (
    tester,
  ) async {
    final harness = await pumpEditor(tester, reduceMotion: true);

    await tester.tap(find.byKey(const ValueKey<String>('editor_tool_light')));
    await tester.pump();
    expect(find.byType(Slider), findsOneWidget);

    await drain(tester, harness);
  });
}
