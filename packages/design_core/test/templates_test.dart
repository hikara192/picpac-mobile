import 'dart:convert';

import 'package:design_core/design_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

const FormatSpec print10x15Format = FormatSpec(
  id: '10x15',
  print: PrintSpec(widthMm: 100, heightMm: 150),
  minPhotos: 1,
  maxPhotos: 1,
);

void main() {
  group('built-in templates', () {
    test('quad template has four non-overlapping slots inside the sheet', () {
      const template = BuiltInTemplates.quad10x15;
      expect(template.slots.length, 4);
      final area = template.slots.fold<double>(
        0,
        (sum, s) => sum + s.rect.area,
      );
      expect(area, lessThanOrEqualTo(1 + kUnitEpsilon));
      for (var i = 0; i < template.slots.length; i++) {
        expect(template.slots[i].rect.isValidUnitRect, isTrue);
        for (var j = i + 1; j < template.slots.length; j++) {
          expect(
            template.slots[i].rect.intersects(template.slots[j].rect),
            isFalse,
          );
        }
      }
      expect(TemplateValidator.validateGeometry(template).isValid, isTrue);
    });

    test('all built-in templates pass geometry validation', () {
      for (final template in BuiltInTemplates.all) {
        final validation = TemplateValidator.validateGeometry(template);
        expect(validation.isValid, isTrue, reason: '${validation.issues}');
        expect(template.slots, isNotEmpty);
        expect(template.nameKey, startsWith('template.'));
      }
    });

    test('every required stage-0 template exists', () {
      expect(
        BuiltInTemplates.byId.keys,
        containsAll(<String>[
          'single_10x15',
          'duo_10x15',
          'quad_10x15',
          'single_3x4',
        ]),
      );
      expect(BuiltInTemplates.single10x15.slotCount, 1);
      expect(BuiltInTemplates.duo10x15.slotCount, 2);
    });

    test('server templates win over built-ins with the same id', () {
      const serverTemplate = PrintTemplate(
        id: 'single_10x15',
        nameKey: 'template.single_10x15_server',
        kind: TemplateKind.print,
        slots: <TemplateSlot>[
          TemplateSlot(
            id: 'main',
            rect: NormalizedRect(x: 0.1, y: 0.1, w: 0.8, h: 0.8),
          ),
        ],
      );
      final merged = BuiltInTemplates.mergedWith(<String, PrintTemplate>{
        serverTemplate.id: serverTemplate,
      });
      expect(merged['single_10x15']!.nameKey, 'template.single_10x15_server');
      expect(merged['quad_10x15']!.id, 'quad_10x15');
    });
  });

  group('template validation', () {
    test('single template matches the 10×15 format', () {
      final validation = TemplateValidator.validateForFormat(
        BuiltInTemplates.single10x15,
        print10x15Format,
      );
      expect(validation.isValid, isTrue, reason: '${validation.issues}');
    });

    test('quad template exceeds the one-photo limit of photo prints', () {
      final validation = TemplateValidator.validateForFormat(
        BuiltInTemplates.quad10x15,
        print10x15Format,
      );
      expect(validation.codes, contains(TemplateIssueCode.slotCountOutOfRange));
    });

    test('3×4 template does not match a 10×15 format aspect', () {
      final validation = TemplateValidator.validateForFormat(
        BuiltInTemplates.single3x4,
        print10x15Format,
      );
      expect(validation.codes, contains(TemplateIssueCode.aspectMismatch));
    });

    test('allow-list rejects a template the server did not offer', () {
      const format = FormatSpec(
        id: '10x15',
        print: PrintSpec(widthMm: 100, heightMm: 150),
        allowedTemplateIds: <String>{'duo_10x15'},
      );
      final validation = TemplateValidator.validateForFormat(
        BuiltInTemplates.single10x15,
        format,
      );
      expect(validation.codes, contains(TemplateIssueCode.templateNotAllowed));
    });

    test('overlapping slots are detected', () {
      const template = PrintTemplate(
        id: 'broken',
        nameKey: 'template.broken',
        kind: TemplateKind.collage,
        slots: <TemplateSlot>[
          TemplateSlot(id: 'a', rect: NormalizedRect.unit),
          TemplateSlot(
            id: 'b',
            rect: NormalizedRect(x: 0.5, y: 0.5, w: 0.4, h: 0.4),
          ),
        ],
      );
      final validation = TemplateValidator.validateGeometry(template);
      expect(validation.codes, contains(TemplateIssueCode.slotsOverlap));
      expect(validation.issuesFor('b'), isNotEmpty);
    });

    test('template JSON round-trips and rejects duplicate slot ids', () {
      final json = jsonDecode(jsonEncode(BuiltInTemplates.quad10x15.toJson()));
      final decoded = PrintTemplate.fromJson(json);
      expect(decoded.isOk, isTrue, reason: '${decoded.failureOrNull}');
      expect(decoded.requireValue, BuiltInTemplates.quad10x15);

      final broken = BuiltInTemplates.quad10x15.toJson();
      final slots = broken['slots']! as List<Object?>;
      (slots[1]! as Map<String, Object?>)['id'] =
          (slots[0]! as Map<String, Object?>)['id'];
      expect(
        PrintTemplate.fromJson(broken).failureOrNull!.code,
        DesignFormatErrorCode.duplicateId,
      );
    });
  });

  group('layout command', () {
    test('keeps framing for slots that survive a template change', () {
      final document = DesignDocument(
        product: printProduct,
        spreads: <Spread>[
          Spread(
            id: 's0',
            templateId: 'single_10x15',
            background: SpreadBackground.color('#FFFFFF'),
            slots: <Slot>[
              const Slot(
                id: 'main',
                photoId: 'p0',
                crop: Crop(x: 0.1, y: 0.1, w: 0.5, h: 0.5),
                zoom: 1.5,
              ),
            ],
          ),
        ],
        spreadsCount: 1,
        assets: <PhotoAsset>[asset('p0')],
      );
      const duo = PrintTemplate(
        id: 'duo_custom',
        nameKey: 'template.duo_custom',
        kind: TemplateKind.print,
        slots: <TemplateSlot>[
          TemplateSlot(
            id: 'main',
            rect: NormalizedRect(x: 0, y: 0, w: 1, h: 0.5),
          ),
          TemplateSlot(
            id: 'extra',
            rect: NormalizedRect(x: 0, y: 0.5, w: 1, h: 0.5),
          ),
        ],
      );
      final after = const SetLayout(
        spreadId: 's0',
        template: duo,
      ).apply(document);
      final spread = after.spreads.single;
      expect(spread.templateId, 'duo_custom');
      expect(spread.slots.length, 2);
      expect(spread.slots.first.id, 'main');
      expect(spread.slots.first.photoId, 'p0');
      expect(spread.slots.first.zoom, 1.5);
      expect(spread.slots.last.photoId, isNull);
      expect(after.assets.length, 1, reason: 'photos are never dropped');
    });
  });
}
