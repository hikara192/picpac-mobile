import 'package:design_core/design_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  group('undo stack', () {
    test('slider coalesces 20 steps into one undo entry', () {
      final document = tenPhotoProject();
      final stack = UndoStack(document: document);

      stack.beginGroup('exposure slider');
      for (var step = 1; step <= 20; step++) {
        final result = stack.execute(
          SetPhotoAdjustment(
            photoId: 'p0',
            field: PhotoAdjustmentField.exposure,
            value: step / 10,
          ),
        );
        expect(result.isOk, isTrue);
      }
      stack.endGroup();

      expect(stack.undoDepth, 1);
      expect(stack.document.revision, document.revision + 1);
      expect(
        stack.document.photoAdjustments['p0']!.exposure,
        closeTo(2.0, 1e-9),
      );

      expect(stack.undo(), isTrue);
      expect(stack.document, document);
      expect(stack.canUndo, isFalse);
      expect(stack.canRedo, isTrue);

      expect(stack.redo(), isTrue);
      expect(
        stack.document.photoAdjustments['p0']!.exposure,
        closeTo(2.0, 1e-9),
      );
    });

    test('coalescing without a group merges consecutive same-field steps', () {
      final document = tenPhotoProject();
      final stack = UndoStack(document: document);
      for (var step = 1; step <= 20; step++) {
        stack.execute(
          SetPhotoAdjustment(
            photoId: 'p0',
            field: PhotoAdjustmentField.saturation,
            value: step.toDouble(),
          ),
        );
      }
      expect(stack.undoDepth, 1);
      expect(stack.undo(), isTrue);
      expect(
        stack.document.photoAdjustments['p0'],
        isNull,
        reason: 'undo restores the neutral stack (entry removed)',
      );
      expect(stack.document.spreads, document.spreads);
      expect(stack.document.assets, document.assets);
    });

    test('a different field starts a new undo entry', () {
      final document = tenPhotoProject();
      final stack = UndoStack(document: document);
      stack.execute(
        const SetPhotoAdjustment(
          photoId: 'p0',
          field: PhotoAdjustmentField.exposure,
          value: 0.5,
        ),
      );
      stack.execute(
        const SetPhotoAdjustment(
          photoId: 'p0',
          field: PhotoAdjustmentField.contrast,
          value: 10,
        ),
      );
      expect(stack.undoDepth, 2);
    });

    test('seal breaks the coalescing run', () {
      final document = tenPhotoProject();
      final stack = UndoStack(document: document);
      stack.execute(
        const SetPhotoAdjustment(
          photoId: 'p0',
          field: PhotoAdjustmentField.exposure,
          value: 0.5,
        ),
      );
      stack.seal();
      stack.execute(
        const SetPhotoAdjustment(
          photoId: 'p0',
          field: PhotoAdjustmentField.exposure,
          value: 1.0,
        ),
      );
      expect(stack.undoDepth, 2);
    });

    test('depth is limited and the oldest entry is dropped', () {
      final document = tenPhotoProject();
      final stack = UndoStack(document: document, limit: 3);
      for (var i = 0; i < 10; i++) {
        stack.execute(
          AssignPhoto(
            spreadId: 's$i',
            slotId: 'main',
            photoId: 'p${(i + 1) % 10}',
          ),
        );
      }
      expect(stack.undoDepth, 3);
      var undone = 0;
      while (stack.undo()) {
        undone++;
      }
      expect(undone, 3);
    });

    test('invalid command changes nothing', () {
      final document = tenPhotoProject();
      final stack = UndoStack(document: document);
      final result = stack.execute(const RemovePhoto(photoId: 'missing'));
      expect(result, isA<CommandFailed>());
      expect(stack.document, document);
      expect(stack.undoDepth, 0);
    });

    test('undo is rejected while a group is open', () {
      final document = tenPhotoProject();
      final stack = UndoStack(document: document);
      stack.beginGroup();
      stack.execute(
        const SetPhotoAdjustment(
          photoId: 'p0',
          field: PhotoAdjustmentField.exposure,
          value: 0.5,
        ),
      );
      expect(stack.canUndo, isFalse);
      expect(stack.undo(), isFalse);
      stack.endGroup();
      expect(stack.canUndo, isTrue);
    });

    test('listeners are notified on apply, undo, redo and grouping', () {
      final document = tenPhotoProject();
      final stack = UndoStack(document: document);
      var notifications = 0;
      void listener() => notifications++;
      stack.addListener(listener);

      stack.execute(
        const SetPhotoAdjustment(
          photoId: 'p0',
          field: PhotoAdjustmentField.exposure,
          value: 0.5,
        ),
      );
      stack.undo();
      stack.redo();
      stack.beginGroup();
      stack.endGroup();
      stack.removeListener(listener);

      expect(notifications, greaterThanOrEqualTo(4));
    });

    test('reset replaces the document and clears history', () {
      final document = tenPhotoProject();
      final stack = UndoStack(document: document);
      stack.execute(
        const SetPhotoAdjustment(
          photoId: 'p0',
          field: PhotoAdjustmentField.exposure,
          value: 0.5,
        ),
      );
      final other = tenPhotoProject();
      stack.reset(other);
      expect(stack.document, other);
      expect(stack.canUndo, isFalse);
      expect(stack.canRedo, isFalse);
    });
  });

  group('remove photo cascade', () {
    test('removing a photo clears slots, adjustments and manifest', () {
      final document = tenPhotoProject().copyWith(
        photoAdjustments: <String, PhotoAdjustment>{
          'p0': const PhotoAdjustment(exposure: 0.4),
        },
      );
      final after = const RemovePhoto(photoId: 'p0').apply(document);
      expect(after.assetById('p0'), isNull);
      expect(after.photoAdjustments.containsKey('p0'), isFalse);
      expect(after.slotById('s0', 'main')!.photoId, isNull);
      expect(after.slotsForPhoto('p0'), isEmpty);

      final restored = const RemovePhoto(photoId: 'p0')
          .invert(document)
          .apply(after);
      expect(restored, document);
    });
  });

  group('photo order', () {
    test('reordering the manifest reorders printed photos', () {
      final document = tenPhotoProject();
      final after = const ReorderPhotos(
        fromIndex: 0,
        toIndex: 9,
      ).apply(document);
      expect(after.orderedPhotoIds.first, 'p1');
      expect(after.orderedPhotoIds.last, 'p0');
      expect(after.assetIdsOrder(), <String>[
        'p1',
        'p2',
        'p3',
        'p4',
        'p5',
        'p6',
        'p7',
        'p8',
        'p9',
        'p0',
      ]);
    });
  });
}

extension on DesignDocument {
  List<String> assetIdsOrder() => <String>[
    for (final asset in assets) asset.id,
  ];
}
