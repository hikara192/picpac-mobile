import 'dart:math' as math;

import 'package:design_core/design_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

typedef CommandFactory = DesignCommand Function(DesignDocument document);

void main() {
  group('command inversion (property, 100 random documents)', () {
    final random = math.Random(20261111);
    final documents = <DesignDocument>[
      for (var i = 0; i < 100; i++) randomDocument(random, index: i),
    ];

    final factories = <String, CommandFactory>{
      'AddPhoto': (document) => AddPhoto(
        photo: asset(
          'new-photo-${document.revision}',
          widthPx: 1200,
          heightPx: 1600,
        ),
        index: document.assets.isEmpty ? null : 0,
      ),
      'RemovePhoto': (document) => RemovePhoto(
        photoId: document.assets[document.revision % document.assets.length].id,
      ),
      'ReorderPhotos': (document) =>
          ReorderPhotos(fromIndex: 0, toIndex: document.assets.length - 1),
      'SetCrop': (document) {
        final spread = document.spreads.first;
        final slot = spread.slots.first;
        return SetCrop(
          spreadId: spread.id,
          slotId: slot.id,
          crop: const Crop(x: 0.1, y: 0.1, w: 0.5, h: 0.6),
          zoom: 2.5,
          anchor: const NormalizedPoint(0.3, 0.7),
        );
      },
      'SetPhotoAdjustment': (document) => SetPhotoAdjustment(
        photoId: document.assets.first.id,
        field: PhotoAdjustmentField.exposure,
        value: 7.5, // deliberately out of range: must be clamped
      ),
      'SetLook': (document) => SetLook(
        photoId: document.assets.first.id,
        look: const LookSetting(id: 'soft', strength: 0.4),
      ),
      'ApplyLook': (document) => ApplyLook(
        photoIds: <String>[for (final asset in document.assets) asset.id],
        lookId: 'warm',
        strength: 0.8,
      ),
      'SetLayout': (document) => SetLayout(
        spreadId: document.spreads.first.id,
        template: BuiltInTemplates.quad10x15,
      ),
      'AssignPhoto': (document) => AssignPhoto(
        spreadId: document.spreads.first.id,
        slotId: document.spreads.first.slots.first.id,
        photoId: document.assets.last.id,
      ),
      'ReorderSpreads': (document) =>
          ReorderSpreads(fromIndex: 0, toIndex: document.spreads.length - 1),
      'SetCover': (document) => SetCover(spreadId: document.spreads.last.id),
      'SetText': (document) => SetText(
        element: TextElement(
          id: 'text-${document.revision}',
          spreadId: document.spreads.first.id,
          text: 'Hello PicPac',
          box: const NormalizedRect(x: 0.1, y: 0.1, w: 0.6, h: 0.2),
        ),
      ),
      'RemoveText': (document) => RemoveText(
        textId: document.text.isEmpty ? 'missing' : document.text.first.id,
      ),
      'SetBackground': (document) => SetBackground(
        spreadId: document.spreads.first.id,
        background: SpreadBackground.color('#FAF5ED'),
      ),
      'SetSlotOrientation': (document) => SetSlotOrientation(
        spreadId: document.spreads.first.id,
        slotId: document.spreads.first.slots.first.id,
        rotation: 90,
        flipH: true,
      ),
      'SetSlotOrientation.cw270': (document) => SetSlotOrientation(
        spreadId: document.spreads.last.id,
        slotId: document.spreads.last.slots.last.id,
        rotation: 270,
        flipH: false,
      ),
      'SwapSlots': (document) {
        final spread = document.spreads.first;
        if (spread.slots.length >= 2) {
          return SwapSlots(
            spreadA: spread.id,
            slotA: spread.slots.first.id,
            spreadB: spread.id,
            slotB: spread.slots.last.id,
          );
        }
        return SwapSlots(
          spreadA: document.spreads.first.id,
          slotA: document.spreads.first.slots.first.id,
          spreadB: document.spreads.last.id,
          slotB: document.spreads.last.slots.first.id,
        );
      },
      'ApplyLayoutPlan': (document) => ApplyLayoutPlan(
        LayoutPlanner.planSheets(
          photos: document.assets,
          templates: BuiltInTemplates.all,
        ),
      ),
    };

    for (final entry in factories.entries) {
      test('${entry.key}: apply then invert restores the exact document', () {
        var applied = 0;
        for (final document in documents) {
          final command = entry.value(document);
          if (command.validate(document) is CommandFailed) continue;
          final after = command.apply(document);
          expect(
            after.revision,
            document.revision + command.revisionDelta,
            reason: '${entry.key} must advance revision by its delta',
          );
          final inverse = command.invert(document);
          final restored = inverse.apply(after);
          expect(restored, document, reason: '${entry.key} must be invertible');
          expect(
            restored.revision,
            document.revision,
            reason: '${entry.key} invert must restore revision',
          );
          expect(restored.toJson(), document.toJson());
          applied++;
        }
        expect(applied, greaterThan(20), reason: 'too few valid samples');
      });
    }
  });

  group('revision bookkeeping', () {
    test('each applied command bumps revision by one', () {
      final document = tenPhotoProject();
      final command = AssignPhoto(
        spreadId: 's0',
        slotId: 'main',
        photoId: 'p1',
      );
      expect(command.apply(document).revision, document.revision + 1);
    });

    test('composite advances revision once and reverts once', () {
      final document = tenPhotoProject();
      final composite = CompositeCommand(<DesignCommand>[
        AssignPhoto(spreadId: 's0', slotId: 'main', photoId: 'p1'),
        AssignPhoto(spreadId: 's1', slotId: 'main', photoId: 'p2'),
      ]);
      final after = composite.apply(document);
      expect(after.revision, document.revision + 1);
      final restored = composite.invert(document).apply(after);
      expect(restored, document);
      expect(restored.revision, document.revision);
    });
  });
}
