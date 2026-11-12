import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/features/inspiration/presentation/widgets/template_preview.dart';

import 'inspiration_fixtures.dart';

void main() {
  test('slotAt находит кадр по той же геометрии, что и painter', () {
    const size = Size(200, 300);
    final slots = stackedSlots(2);

    expect(TemplatePreview.slotAt(const Offset(100, 40), size, slots), 0);
    expect(TemplatePreview.slotAt(const Offset(100, 260), size, slots), 1);
    expect(TemplatePreview.slotAt(const Offset(2, 2), size, slots), isNull);
  });

  testWidgets('превью рисуется по слотам и не требует ассетов', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 200,
            child: TemplatePreview(
              slots: gridSlots(),
              aspect: 2 / 3,
              selectedSlot: 1,
              semanticLabel: 'Макет тестового шаблона',
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(Image), findsNothing);
    expect(find.bySemanticsLabel('Макет тестового шаблона'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
