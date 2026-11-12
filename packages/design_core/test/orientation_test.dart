import 'package:design_core/design_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  group('slot orientation serialization', () {
    test('the default orientation is not written and not needed to read', () {
      const slot = Slot(id: 'main', photoId: 'p0');
      final json = slot.toJson();
      expect(json.containsKey('rotation'), isFalse);
      expect(json.containsKey('flipH'), isFalse);

      final decoded = Slot.fromJson(<String, Object?>{
        'id': 'main',
        'photoId': 'p0',
        'crop': Crop.full.toJson(),
        'zoom': 1,
        'anchor': NormalizedPoint.center.toJson(),
      }, r'$.slot');
      expect(decoded.rotation, QuarterTurn.none);
      expect(decoded.flipH, isFalse);
      expect(decoded.toJson(), json);
    });

    test('a turned and mirrored slot round-trips through JSON', () {
      const slot = Slot(
        id: 'main',
        photoId: 'p0',
        rotation: QuarterTurn.cw270,
        flipH: true,
      );
      final json = slot.toJson();
      expect(json['rotation'], 270);
      expect(json['flipH'], true);
      expect(Slot.fromJson(json, r'$.slot'), slot);
    });

    test('a non-right angle is rejected on parse', () {
      expect(
        () => Slot.fromJson(<String, Object?>{
          'id': 'main',
          'crop': Crop.full.toJson(),
          'zoom': 1,
          'anchor': NormalizedPoint.center.toJson(),
          'rotation': 45,
        }, r'$.slot'),
        throwsA(
          isA<DesignFormatException>().having(
            (error) => error.code,
            'code',
            DesignFormatErrorCode.outOfRange,
          ),
        ),
      );
    });

    test('a document keeps the orientation through a full round-trip', () {
      final document = tenPhotoProject().copyWith(
        spreads: <Spread>[
          tenPhotoProject().spreads.first.copyWith(
            slots: <Slot>[
              const Slot(
                id: 'main',
                photoId: 'p0',
                rotation: QuarterTurn.cw90,
                flipH: true,
              ),
            ],
          ),
        ],
      );
      final decoded = DesignDocument.fromJson(document.toJson());
      expect(decoded.isOk, isTrue, reason: '${decoded.failureOrNull}');
      expect(decoded.requireValue, document);
    });
  });

  group('SetSlotOrientation', () {
    test('rejects a rotation that is not a right angle', () {
      final document = tenPhotoProject();
      final result = const SetSlotOrientation(
        spreadId: 's0',
        slotId: 'main',
        rotation: 45,
        flipH: false,
      ).validate(document);
      expect(result, isA<CommandFailed>());
      expect(result.error!.code, CommandErrorCode.invalidValue);
      expect(result.error!.args['rotation'], 45);
    });

    test('rejects an unknown spread or slot with a typed error', () {
      final document = tenPhotoProject();
      expect(
        const SetSlotOrientation(
          spreadId: 'nope',
          slotId: 'main',
          rotation: 90,
          flipH: false,
        ).validate(document).error!.code,
        CommandErrorCode.spreadNotFound,
      );
      expect(
        const SetSlotOrientation(
          spreadId: 's0',
          slotId: 'nope',
          rotation: 90,
          flipH: false,
        ).validate(document).error!.code,
        CommandErrorCode.slotNotFound,
      );
    });

    test('writes both orientation fields and inverts exactly', () {
      final document = tenPhotoProject();
      const command = SetSlotOrientation(
        spreadId: 's0',
        slotId: 'main',
        rotation: 270,
        flipH: true,
      );
      final after = command.apply(document);
      final slot = after.slotById('s0', 'main')!;
      expect(slot.rotation, QuarterTurn.cw270);
      expect(slot.flipH, isTrue);

      final restored = command.invert(document).apply(after);
      expect(restored, document);
      expect(restored.revision, document.revision);
    });

    test('three quick taps are one undo entry and undo to the start', () {
      final document = tenPhotoProject();
      final stack = UndoStack(document: document);
      for (var i = 0; i < 3; i++) {
        stack.execute(
          const SetSlotOrientation(
            spreadId: 's0',
            slotId: 'main',
            rotation: 90,
            flipH: false,
          ),
        );
      }
      expect(stack.undoDepth, 1, reason: 'taps on the same slot must coalesce');
      expect(stack.undo(), isTrue);
      expect(stack.document.spreads, document.spreads);
      final slot = stack.document.slotById('s0', 'main')!;
      expect(slot.rotation, QuarterTurn.none);
      expect(slot.flipH, isFalse);
    });

    test('a different slot breaks the coalescing run', () {
      final stack = UndoStack(document: tenPhotoProject());
      stack.execute(
        const SetSlotOrientation(
          spreadId: 's0',
          slotId: 'main',
          rotation: 90,
          flipH: false,
        ),
      );
      stack.execute(
        const SetSlotOrientation(
          spreadId: 's1',
          slotId: 'main',
          rotation: 90,
          flipH: false,
        ),
      );
      expect(stack.undoDepth, 2);
    });
  });

  group('SwapSlots', () {
    test('exchanges photo and framing, not just the id', () {
      final base = tenPhotoProject();
      final document = base.copyWith(
        spreads: <Spread>[
          base.spreads[0].copyWith(
            slots: <Slot>[
              const Slot(
                id: 'main',
                photoId: 'p0',
                crop: Crop(x: 0.1, y: 0.1, w: 0.5, h: 0.5),
                zoom: 2,
                anchor: NormalizedPoint(0.2, 0.8),
                rotation: QuarterTurn.cw90,
                flipH: true,
              ),
            ],
          ),
          base.spreads[1],
        ],
      );
      const command = SwapSlots(
        spreadA: 's0',
        slotA: 'main',
        spreadB: 's1',
        slotB: 'main',
      );
      final after = command.apply(document);
      final first = after.slotById('s0', 'main')!;
      final second = after.slotById('s1', 'main')!;
      expect(first.photoId, 'p1');
      expect(first.crop, Crop.full, reason: 'framing travels with the photo');
      expect(first.zoom, Slot.minZoom);
      expect(first.rotation, QuarterTurn.none);
      expect(second.photoId, 'p0');
      expect(second.crop, const Crop(x: 0.1, y: 0.1, w: 0.5, h: 0.5));
      expect(second.rotation, QuarterTurn.cw90);
      expect(second.flipH, isTrue);
      expect(after.revision, document.revision + 1);
    });

    test('is its own inverse', () {
      final document = tenPhotoProject();
      const command = SwapSlots(
        spreadA: 's0',
        slotA: 'main',
        spreadB: 's3',
        slotB: 'main',
      );
      final after = command.apply(document);
      expect(command.invert(document).apply(after), document);
    });

    test('rejects swapping a slot with itself and missing slots', () {
      final document = tenPhotoProject();
      expect(
        const SwapSlots(
          spreadA: 's0',
          slotA: 'main',
          spreadB: 's0',
          slotB: 'main',
        ).validate(document).error!.code,
        CommandErrorCode.invalidTarget,
      );
      expect(
        const SwapSlots(
          spreadA: 's0',
          slotA: 'main',
          spreadB: 's0',
          slotB: 'other',
        ).validate(document).error!.code,
        CommandErrorCode.slotNotFound,
      );
      expect(
        const SwapSlots(
          spreadA: 'nope',
          slotA: 'main',
          spreadB: 's0',
          slotB: 'main',
        ).validate(document).error!.code,
        CommandErrorCode.spreadNotFound,
      );
    });

    test('one swap is one undo entry', () {
      final document = tenPhotoProject();
      final stack = UndoStack(document: document);
      stack.execute(
        const SwapSlots(
          spreadA: 's0',
          slotA: 'main',
          spreadB: 's1',
          slotB: 'main',
        ),
      );
      expect(stack.undoDepth, 1);
      expect(stack.undo(), isTrue);
      expect(stack.document, document);
    });
  });

  group('preflight and rotation', () {
    const portraitSpec = PrintSpec(widthMm: 25.4, heightMm: 50.8);

    DesignDocument project(PhotoAsset photo, {required QuarterTurn rotation}) =>
        DesignDocument(
          product: printProduct,
          spreads: <Spread>[
            Spread(
              id: 's0',
              templateId: BuiltInTemplates.single10x15Id,
              background: SpreadBackground.color('#FFFFFF'),
              slots: <Slot>[
                Slot(id: 'main', photoId: photo.id, rotation: rotation),
              ],
            ),
          ],
          spreadsCount: 1,
          assets: <PhotoAsset>[photo],
        );

    test('exactly 300 dpi in a portrait slot passes', () {
      final report = PreflightProjection.run(
        document: project(
          asset('p0', widthPx: 300, heightPx: 600),
          rotation: QuarterTurn.none,
        ),
        spec: portraitSpec,
      );
      expect(report.codes, isNot(contains(PreflightCode.lowDpi)));
    });

    test('turning the slot 90° swaps the axes and reports LOW_DPI', () {
      final report = PreflightProjection.run(
        document: project(
          asset('p0', widthPx: 300, heightPx: 600),
          rotation: QuarterTurn.cw90,
        ),
        spec: portraitSpec,
      );
      expect(report.codes, contains(PreflightCode.lowDpi));
      final issue = report.issuesFor('main').single;
      expect(issue.args['effectiveDpi'], 150);
      expect(issue.args['axesSwapped'], isTrue);
      expect(issue.args['rotation'], 90);
      expect(issue.args['sourcePx'], '600×300');
      expect(issue.args['requiredPx'], '300×600');
    });

    test('a landscape photo becomes printable after a quarter turn', () {
      final photo = asset('p0', widthPx: 600, heightPx: 300);
      final before = PreflightProjection.run(
        document: project(photo, rotation: QuarterTurn.none),
        spec: portraitSpec,
      );
      expect(before.codes, contains(PreflightCode.lowDpi));

      final after = PreflightProjection.run(
        document: project(photo, rotation: QuarterTurn.cw90),
        spec: portraitSpec,
      );
      expect(after.codes, isNot(contains(PreflightCode.lowDpi)));
    });

    test('180° does not swap the axes', () {
      final report = PreflightProjection.run(
        document: project(
          asset('p0', widthPx: 300, heightPx: 600),
          rotation: QuarterTurn.cw180,
        ),
        spec: portraitSpec,
      );
      expect(report.codes, isNot(contains(PreflightCode.lowDpi)));
    });
  });
}
