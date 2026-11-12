import 'package:api_contract/api_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:picpac_mobile/features/_shared/application/design_session.dart';
import 'package:picpac_mobile/features/inspiration/application/template_applier.dart';

import '../support/design_fixtures.dart';
import '../support/design_harness.dart';
import 'inspiration_fixtures.dart';

void main() {
  setUpAll(registerDesignFallbacks);

  const duo = ProductTemplate(
    id: 'duo_10x15',
    nameKey: 'template.duo_10x15',
    kind: TemplateKind.collage,
    aspect: 0.6710526315789473,
    slots: <TemplateSlot>[
      TemplateSlot(id: 'top', rect: NormalizedRect(x: 0, y: 0, w: 1, h: 0.49)),
      TemplateSlot(
        id: 'bottom',
        rect: NormalizedRect(x: 0, y: 0.51, w: 1, h: 0.49),
      ),
    ],
  );

  DesignDocument documentWithTwoPhotos() =>
      AutoLayoutSheets(template: duo.toPrintTemplate()).applyCore(
        DesignDocument(
          product: const DocumentProduct(id: 'photo_print', formatId: '10x15'),
          assets: <PhotoAsset>[
            photoAsset(id: 'p1', widthPx: 1200, heightPx: 900),
            photoAsset(id: 'p2', widthPx: 900, heightPx: 1200),
          ],
        ),
      );

  void stubProjectCalls(
    DesignHarness harness, {
    required ProductFormat format,
    required DesignDocument serverDocument,
  }) {
    when(() => harness.api.catalog())
        .thenAnswer((_) async => Ok<CatalogResponse>(catalogWith(format)));
    when(() => harness.api.product(any()))
        .thenAnswer((_) async => Ok<Product>(printProduct(format)));
    when(() => harness.api.design(any())).thenAnswer(
      (invocation) async => Ok<DesignDto>(
        designDto(
          id: invocation.positionalArguments[0] as String,
          document: serverDocument,
        ),
      ),
    );
    when(() => harness.api.createDesign(any())).thenAnswer((invocation) async {
      final document = invocation.positionalArguments[0] as DesignDocument;
      return Ok<DesignDto>(
        DesignDto(
          id: 'dsg_new',
          revision: 1,
          document: document,
          updatedAt: DateTime.utc(2026, 11, 11, 12),
        ),
      );
    });
    when(
      () => harness.api.putDesign(
        any(),
        any(),
        ifMatchRevision: any(named: 'ifMatchRevision'),
      ),
    ).thenAnswer(
      (invocation) async => Ok<DesignDto>(
        DesignDto(
          id: invocation.positionalArguments[0] as String,
          revision: 2,
          document: invocation.positionalArguments[1] as DesignDocument,
          updatedAt: DateTime.utc(2026, 11, 11, 12, 5),
        ),
      ),
    );
  }

  testWidgets('без черновика идея создаёт проект и применяет шаблон', (
    tester,
  ) async {
    final idea = duoIdea();
    final format = formatWithTemplates(printFormat(), <ProductTemplate>[
      templateOf(idea),
    ]);
    final harness = await DesignHarness.forWidgetTest(tester, format: format);
    stubProjectCalls(
      harness,
      format: format,
      serverDocument: DesignDocument.start(
        product: const DocumentProduct(id: 'photo_print', formatId: '10x15'),
      ),
    );
    final container = harness.mount();

    final outcome = await tester.runAsync(
      () => container.read(templateApplierProvider).apply(detailOf(idea)),
    );

    expect(outcome!.isApplied, isTrue, reason: '${outcome.problem}');
    expect(outcome.designId, 'dsg_new');
    final session = await tester.runAsync(
      () => container.read(designSessionProvider('dsg_new').future),
    );
    expect(session!.spreads, hasLength(1));
    expect(session.spreads.first.templateId, 'insp_duo_split');
    expect(
      session.spreads.first.slots.map((slot) => slot.photoId),
      everyElement(isNull),
      reason: 'новый проект раскладывается пустыми кадрами шаблона',
    );
    verify(() => harness.api.createDesign(any())).called(1);

    container.dispose();
    await harness.disposeForTest(tester);
  });

  testWidgets('открытый черновик получает SetLayout одним шагом undo', (
    tester,
  ) async {
    final idea = duoIdea();
    final format = formatWithTemplates(printFormat(), <ProductTemplate>[
      duo,
      templateOf(idea),
      templateOf(quadIdea()),
    ]);
    final document = documentWithTwoPhotos();
    final harness = await DesignHarness.forWidgetTest(tester, format: format);
    await tester.runAsync(
      () => harness.drafts.saveNow(
        document,
        designId: 'dsg_1',
        productId: 'photo_print',
      ),
    );
    stubProjectCalls(harness, format: format, serverDocument: document);
    final container = harness.mount();

    final outcome = await tester.runAsync(
      () => container.read(templateApplierProvider).apply(detailOf(idea)),
    );

    expect(outcome!.designId, 'dsg_1');
    final session = container.read(designSessionProvider('dsg_1')).value;
    expect(session, isNotNull);
    expect(session!.spreads.first.templateId, 'insp_duo_split');
    expect(session.spreads.first.slots.map((slot) => slot.photoId), <String>[
      'p1',
      'p2',
    ]);
    expect(session.canUndo, isTrue);

    expect(
      container.read(designSessionProvider('dsg_1').notifier).undo(),
      isTrue,
    );
    final restored = container.read(designSessionProvider('dsg_1')).value!;
    expect(restored.spreads.first.templateId, 'duo_10x15');

    container.dispose();
    await harness.disposeForTest(tester);
  });

  testWidgets('шаблон на 4 кадра не ломает проект с двумя фото', (
    tester,
  ) async {
    final idea = quadIdea();
    final format = formatWithTemplates(printFormat(), <ProductTemplate>[
      duo,
      templateOf(duoIdea()),
      templateOf(idea),
    ]);
    final document = documentWithTwoPhotos();
    final harness = await DesignHarness.forWidgetTest(tester, format: format);
    await tester.runAsync(
      () => harness.drafts.saveNow(
        document,
        designId: 'dsg_1',
        productId: 'photo_print',
      ),
    );
    stubProjectCalls(harness, format: format, serverDocument: document);
    final container = harness.mount();

    final outcome = await tester.runAsync(
      () => container.read(templateApplierProvider).apply(detailOf(idea)),
    );

    expect(outcome!.isApplied, isFalse);
    expect(outcome.problem, TemplateApplyProblem.notEnoughPhotos);
    expect(outcome.slotCount, 4);
    expect(outcome.photoCount, 2);
    final session = container.read(designSessionProvider('dsg_1')).value;
    expect(session!.spreads.first.templateId, 'duo_10x15');
    expect(session.canUndo, isFalse);

    container.dispose();
    await harness.disposeForTest(tester);
  });
}
