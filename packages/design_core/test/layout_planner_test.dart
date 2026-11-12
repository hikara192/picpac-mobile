import 'package:design_core/design_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  PhotoAsset portrait(String id) => asset(id, widthPx: 1000, heightPx: 1500);
  PhotoAsset landscape(String id) => asset(id, widthPx: 1500, heightPx: 1000);

  List<PhotoAsset> photos(int count, PhotoAsset Function(String) make) =>
      <PhotoAsset>[for (var i = 0; i < count; i++) make('p$i')];

  DesignDocument project(List<PhotoAsset> assets) =>
      DesignDocument(product: printProduct, assets: assets);

  group('PhotoOrientation', () {
    test('classifies by aspect ratio with the documented thresholds', () {
      expect(PhotoOrientation.ofAspect(0.66), PhotoOrientation.portrait);
      expect(PhotoOrientation.ofAspect(0.9), PhotoOrientation.square);
      expect(PhotoOrientation.ofAspect(1.0), PhotoOrientation.square);
      expect(PhotoOrientation.ofAspect(1.1), PhotoOrientation.square);
      expect(PhotoOrientation.ofAspect(1.78), PhotoOrientation.landscape);
      expect(PhotoOrientation.of(portrait('p')), PhotoOrientation.portrait);
    });
  });

  group('LayoutPlanner.planSheets', () {
    test('ten portrait photos become one cover, two quads and one single', () {
      final plan = LayoutPlanner.planSheets(
        photos: photos(10, portrait),
        templates: BuiltInTemplates.all,
      );
      expect(plan.sheetCount, 4);
      expect(plan.templateIds, <String>[
        BuiltInTemplates.single10x15Id,
        BuiltInTemplates.quad10x15Id,
        BuiltInTemplates.quad10x15Id,
        BuiltInTemplates.single10x15Id,
      ]);
      expect(plan.placedCount, 10);
      expect(plan.emptySlotCount, 0, reason: 'an empty cell is paid for twice');
      expect(plan.photoIds, <String>[
        for (var i = 0; i < 10; i++) 'p$i',
      ], reason: 'the manifest order is the user choice and is preserved');
    });

    test('a dense plan uses fewer sheets than one photo per sheet', () {
      final assets = photos(10, portrait);
      final dense = LayoutPlanner.planSheets(
        photos: assets,
        templates: BuiltInTemplates.all,
      );
      final uniform = LayoutPlanner.uniformPlan(
        template: BuiltInTemplates.single10x15,
        photoIds: <String>[for (final asset in assets) asset.id],
      );
      expect(dense.sheetCount, lessThan(uniform.sheetCount));
      expect(uniform.sheetCount, 10);
    });

    test('fewer than four photos stay one per sheet', () {
      final plan = LayoutPlanner.planSheets(
        photos: photos(3, portrait),
        templates: BuiltInTemplates.all,
      );
      expect(plan.sheetCount, 3);
      expect(plan.emptySlotCount, 0);
      expect(plan.templateIds, everyElement(BuiltInTemplates.single10x15Id));
    });

    test('a dense group never mixes orientations', () {
      final assets = <PhotoAsset>[
        portrait('p0'),
        landscape('p1'),
        landscape('p2'),
        landscape('p3'),
        landscape('p4'),
        portrait('p5'),
      ];
      final plan = LayoutPlanner.planSheets(
        photos: assets,
        templates: BuiltInTemplates.all,
      );
      final byId = <String, PhotoAsset>{
        for (final asset in assets) asset.id: asset,
      };
      for (final sheet in plan.sheets) {
        if (sheet.slotCount == 1) continue;
        final orientations = <PhotoOrientation>{
          for (final id in sheet.photoIds)
            if (id != null) PhotoOrientation.of(byId[id]!),
        };
        expect(
          orientations,
          hasLength(1),
          reason: '${sheet.template.id} mixed',
        );
      }
      expect(plan.emptySlotCount, 0);
      expect(plan.placedCount, 6);
    });

    test('is deterministic', () {
      final assets = photos(10, portrait);
      final first = LayoutPlanner.planSheets(
        photos: assets,
        templates: BuiltInTemplates.all,
      );
      final second = LayoutPlanner.planSheets(
        photos: assets,
        templates: BuiltInTemplates.all,
      );
      expect(second.templateIds, first.templateIds);
      expect(second.photoIds, first.photoIds);
      expect(second.sheetCount, first.sheetCount);
    });

    test('pads to the format minimum with empty single sheets', () {
      final plan = LayoutPlanner.planSheets(
        photos: photos(1, portrait),
        templates: BuiltInTemplates.all,
        minSheets: 3,
      );
      expect(plan.sheetCount, 3);
      expect(plan.emptySlotCount, 2);
    });

    test('falls back to the built-in templates for an empty format', () {
      final plan = LayoutPlanner.planSheets(
        photos: photos(4, portrait),
        templates: const <PrintTemplate>[],
      );
      expect(plan.sheetCount, greaterThan(0));
      expect(plan.placedCount, 4);
    });

    test('every plan from 1 to 12 photos applies without an empty cell', () {
      for (var count = 1; count <= 12; count++) {
        final assets = photos(count, portrait);
        final plan = LayoutPlanner.planSheets(
          photos: assets,
          templates: BuiltInTemplates.all,
        );
        final command = plan.toCommand();
        expect(
          command.validate(project(assets)),
          isA<CommandOk>(),
          reason: '$count photos must produce a valid plan',
        );
        final after = command.apply(project(assets));
        expect(after.emptySlotCount, 0, reason: '$count photos');
        expect(after.orderedPhotoIds, <String>[
          for (final asset in assets) asset.id,
        ], reason: 'print order follows the manifest');
      }
    });

    test('a format with only a four-up template still yields a valid plan', () {
      final assets = photos(4, portrait);
      final plan = LayoutPlanner.planSheets(
        photos: assets,
        templates: <PrintTemplate>[BuiltInTemplates.quad10x15],
      );
      expect(plan.toCommand().validate(project(assets)), isA<CommandOk>());
      expect(plan.templateIds, everyElement(BuiltInTemplates.quad10x15Id));
      expect(plan.placedCount, 4);
    });
  });

  group('LayoutPlan.applyTo', () {
    test('creates the sheets, keeps the framing and counts as one command', () {
      final assets = photos(10, portrait);
      final withFraming = project(assets).copyWith(
        spreads: <Spread>[
          Spread(
            id: 'sheet_1',
            templateId: BuiltInTemplates.single10x15Id,
            background: SpreadBackground.color('#FFFFFF'),
            slots: <Slot>[
              Slot(
                id: 'main',
                photoId: 'p0',
                crop: const Crop(x: 0.1, y: 0.1, w: 0.6, h: 0.6),
                zoom: 2,
                rotation: QuarterTurn.cw90,
              ),
            ],
          ),
        ],
        spreadsCount: 1,
      );
      final plan = LayoutPlanner.planSheets(
        photos: assets,
        templates: BuiltInTemplates.all,
      );
      final after = plan.applyTo(withFraming);
      expect(after.revision, withFraming.revision + 1);
      expect(after.spreads, hasLength(plan.sheetCount));
      expect(after.spreadsCount, plan.sheetCount);
      expect(after.spreads.first.id, 'sheet_1');
      expect(after.spreads.first.background.value, '#FFFFFF');

      final cover = after.spreads.first.slots.single;
      expect(cover.photoId, 'p0');
      expect(cover.crop, const Crop(x: 0.1, y: 0.1, w: 0.6, h: 0.6));
      expect(cover.zoom, 2);
      expect(cover.rotation, QuarterTurn.cw90);
      expect(after.emptySlotCount, 0);
    });

    test('undo restores the previous sheet list in one step', () {
      final assets = photos(10, portrait);
      final document = project(assets);
      final stack = UndoStack(document: document);
      final plan = LayoutPlanner.planSheets(
        photos: assets,
        templates: BuiltInTemplates.all,
      );
      final result = stack.execute(plan.toCommand());
      expect(result, isA<CommandOk>());
      expect(stack.undoDepth, 1);
      expect(stack.undo(), isTrue);
      expect(stack.document, document);
    });

    test('rejects a plan that references an unknown photo', () {
      final document = project(photos(2, portrait));
      final plan = LayoutPlan(<PlannedSheet>[
        PlannedSheet(
          template: BuiltInTemplates.single10x15,
          photoIds: const <String?>['ghost'],
        ),
      ]);
      final result = plan.toCommand().validate(document);
      expect(result, isA<CommandFailed>());
      expect(result.error!.code, CommandErrorCode.photoNotInDocument);
    });

    test('rejects a plan whose slot count does not match the template', () {
      final document = project(photos(2, portrait));
      final plan = LayoutPlan(<PlannedSheet>[
        PlannedSheet(
          template: BuiltInTemplates.quad10x15,
          photoIds: const <String?>['p0', 'p1'],
        ),
      ]);
      expect(
        plan.toCommand().validate(document).error!.code,
        CommandErrorCode.invalidValue,
      );
      expect(LayoutPlan.empty.toCommand().validate(document).isFailed, isTrue);
    });
  });

  group('LayoutPlanner.uniformPlan', () {
    test('fills N photos per sheet in manifest order', () {
      final plan = LayoutPlanner.uniformPlan(
        template: BuiltInTemplates.quad10x15,
        photoIds: const <String>['a', 'b', 'c', 'd', 'e'],
      );
      expect(plan.sheetCount, 2);
      expect(plan.sheets.first.photoIds, <String?>['a', 'b', 'c', 'd']);
      expect(plan.sheets.last.photoIds, <String?>['e', null, null, null]);
      expect(plan.emptySlotCount, 3);
    });

    test('honours the minimum sheet count for an empty project', () {
      final plan = LayoutPlanner.uniformPlan(
        template: BuiltInTemplates.single10x15,
        photoIds: const <String>[],
        minSheets: 2,
      );
      expect(plan.sheetCount, 2);
      expect(plan.placedCount, 0);
    });
  });

  group('AutoLayoutSheets', () {
    test('keeps the stage-0 behaviour and one undo step', () {
      final document = tenPhotoProject();
      final stack = UndoStack(document: document);
      stack.execute(AutoLayoutSheets(template: BuiltInTemplates.quad10x15));
      expect(stack.document.spreads, hasLength(3));
      expect(stack.document.spreads.last.emptySlotCount, 2);
      expect(stack.undoDepth, 1);
      expect(stack.undo(), isTrue);
      expect(stack.document, document);
    });

    test('rejects a template without slots', () {
      final document = tenPhotoProject();
      const empty = PrintTemplate(
        id: 'broken',
        nameKey: 'template.broken',
        kind: TemplateKind.print,
        slots: <TemplateSlot>[],
      );
      expect(
        const AutoLayoutSheets(template: empty).validate(document).error!.code,
        CommandErrorCode.invalidTarget,
      );
    });
  });
}
