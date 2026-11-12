import 'package:design_core/design_core.dart';
import 'package:test/test.dart';

DesignDocument fixture() {
  return DesignDocument(
    revision: 12,
    product: const DocumentProduct(id: 'photo_print', formatId: '10x15'),
    spreadsCount: 2,
    spreads: <Spread>[
      const Spread(
        id: 's1',
        templateId: BuiltInTemplates.duo10x15Id,
        background: SpreadBackground(
          type: BackgroundType.color,
          value: '#FFFFFF',
        ),
        slots: <Slot>[
          Slot(
            id: 'top',
            photoId: 'p1',
            crop: Crop(x: 0, y: 0, w: 0.5, h: 0.5),
            zoom: 2,
          ),
          Slot(id: 'bottom', photoId: 'p2'),
        ],
      ),
      const Spread(
        id: 's2',
        templateId: BuiltInTemplates.duo10x15Id,
        background: SpreadBackground(
          type: BackgroundType.color,
          value: '#FFFFFF',
        ),
        slots: <Slot>[
          Slot(id: 'top'),
          Slot(id: 'bottom'),
        ],
      ),
    ],
    assets: <PhotoAsset>[
      PhotoAsset(
        id: 'p1',
        sha256: List<String>.filled(64, 'a').join(),
        widthPx: 3000,
        heightPx: 2000,
        mimeType: 'image/jpeg',
        bytes: 1000,
      ),
      PhotoAsset(
        id: 'p2',
        sha256: List<String>.filled(64, 'b').join(),
        widthPx: 3000,
        heightPx: 2000,
        mimeType: 'image/jpeg',
        bytes: 1000,
      ),
      PhotoAsset(
        id: 'p3',
        sha256: List<String>.filled(64, 'c').join(),
        widthPx: 3000,
        heightPx: 2000,
        mimeType: 'image/jpeg',
        bytes: 1000,
      ),
    ],
  );
}

void main() {
  group('DesignAdvisor', () {
    test('binds the proposal to the summary revision', () {
      final patch = DesignAdvisor.propose(
        summary: DocumentSummary.from(fixture()),
        intent: AiIntents.warmer,
      );
      expect(patch.baseRevision, 12);
      expect(patch.meta.skillId, DesignAdvisor.skillId);
      expect(patch.meta.model, DesignAdvisor.model);
      expect(patch.meta.toolSchemaVersion, DesignAdvisor.toolSchemaVersion);
    });

    test('a chip code and a phrase produce the same operation', () {
      final summary = DocumentSummary.from(fixture());
      final chip = DesignAdvisor.propose(
        summary: summary,
        intent: AiIntents.warmer,
      );
      final phrase = DesignAdvisor.propose(
        summary: summary,
        intent: 'Сделай, пожалуйста, теплее',
      );
      expect(chip.operations.single, phrase.operations.single);
      final operation = chip.operations.single as SetAdjustmentOperation;
      expect(operation.field, PhotoAdjustmentField.temperature);
      expect(operation.value, DesignAdvisor.warmthStep);
      expect(operation.photoIds, isNull);
    });

    test('black and white applies the mono preset at full strength', () {
      final patch = DesignAdvisor.propose(
        summary: DocumentSummary.from(fixture()),
        intent: 'ч/б',
      );
      final operation = patch.operations.single as ApplyLookOperation;
      expect(operation.lookId, DesignAdvisor.monoLookId);
      expect(operation.strength, 1);
      expect(LookLibrary.containsId(operation.lookId), isTrue);
    });

    test('centres only the frames that are off-centre', () {
      final patch = DesignAdvisor.propose(
        summary: DocumentSummary.from(fixture()),
        intent: AiIntents.alignFrames,
      );
      expect(patch.operations.length, 1);
      final operation = patch.operations.single as SetCropOperation;
      expect(operation.spreadId, 's1');
      expect(operation.slotId, 'top');
      expect(operation.crop.x, closeTo(0.25, 1e-9));
      expect(operation.crop.y, closeTo(0.25, 1e-9));
      expect(operation.crop.w, 0.5);
      expect(operation.zoom, 2);
    });

    test('places free photos into empty slots without duplicating them', () {
      final patch = DesignAdvisor.propose(
        summary: DocumentSummary.from(fixture()),
        intent: AiIntents.fillSlots,
      );
      expect(patch.operations, hasLength(1));
      final operation = patch.operations.first as AssignPhotoOperation;
      expect(operation.photoId, 'p3');
      expect(operation.spreadId, 's2');
      expect(operation.slotId, 'top');
    });

    test('denser names a template the format offers and only when it pays', () {
      final summary = DocumentSummary.from(fixture());
      final withTemplate = DesignAdvisor.propose(
        summary: summary,
        intent: AiIntents.denser,
        templates: <String, int>{
          BuiltInTemplates.duo10x15Id: 2,
          BuiltInTemplates.quad10x15Id: 4,
        },
      );
      expect(withTemplate.operations.single, isA<AssignPhotoOperation>());

      final withoutTemplates = DesignAdvisor.propose(
        summary: summary,
        intent: AiIntents.denser,
      );
      expect(withoutTemplates.isEmpty, isFalse);
    });

    test('an unknown intent produces an empty patch', () {
      final patch = DesignAdvisor.propose(
        summary: DocumentSummary.from(fixture()),
        intent: 'сделай красиво как в инстаграме',
      );
      expect(patch.isEmpty, isTrue);
    });

    test('respects the operation budget', () {
      final document = fixture();
      final many = document.copyWith(
        spreads: <Spread>[
          for (var i = 0; i < 6; i++)
            Spread(
              id: 'x$i',
              templateId: BuiltInTemplates.single10x15Id,
              background: const SpreadBackground(
                type: BackgroundType.color,
                value: '#FFFFFF',
              ),
              slots: <Slot>[
                Slot(
                  id: 'main',
                  photoId: 'p1',
                  crop: const Crop(x: 0, y: 0, w: 0.5, h: 0.5),
                ),
              ],
            ),
        ],
        spreadsCount: 6,
      );
      final patch = DesignAdvisor.propose(
        summary: DocumentSummary.from(many),
        intent: AiIntents.alignFrames,
        maxOps: 3,
      );
      expect(patch.operations, hasLength(3));
    });

    test('is deterministic', () {
      final summary = DocumentSummary.from(fixture());
      final first = DesignAdvisor.propose(
        summary: summary,
        intent: AiIntents.brighter,
      );
      final second = DesignAdvisor.propose(
        summary: summary,
        intent: AiIntents.brighter,
      );
      expect(first, second);
      expect(first.toJson(), second.toJson());
    });
  });
}
