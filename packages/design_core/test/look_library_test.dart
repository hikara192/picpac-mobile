import 'package:design_core/design_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  group('LookLibrary', () {
    test('ships exactly six presets with unique ids and key names', () {
      expect(LookLibrary.presets, hasLength(6));
      expect(LookLibrary.version, greaterThan(0));
      final ids = <String>{};
      for (final preset in LookLibrary.presets) {
        expect(preset.id.trim(), isNotEmpty);
        expect(
          preset.nameKey.startsWith('look'),
          isTrue,
          reason: '${preset.id} must use a localisation key, not prose',
        );
        expect(ids.add(preset.id), isTrue, reason: 'duplicate ${preset.id}');
      }
      expect(LookLibrary.ids, hasLength(6));
      expect(LookLibrary.containsId(LookLibrary.neutralId), isTrue);
    });

    test('the neutral preset changes nothing', () {
      expect(LookLibrary.asIs.isNeutral, isTrue);
      expect(LookLibrary.asIs.asAdjustment(1).isNeutral, isTrue);
      expect(
        LookLibrary.resolve(
          const PhotoAdjustment(
            look: LookSetting(id: LookLibrary.neutralId, strength: 1),
          ),
        ).isNeutral,
        isTrue,
      );
    });

    test('every preset stays inside the document ranges at full strength', () {
      for (final preset in LookLibrary.presets) {
        final adjustment = preset.asAdjustment(1);
        expect(
          adjustment,
          adjustment.clamped(),
          reason: '${preset.id} exceeds AdjustmentLimits',
        );
      }
    });

    test('presets are skin-safe at full strength', () {
      for (final preset in LookLibrary.presets) {
        final adjustment = preset.asAdjustment(1);
        expect(
          adjustment.temperature.abs(),
          lessThanOrEqualTo(20),
          reason: '${preset.id} warms too much',
        );
        expect(
          adjustment.tint.abs(),
          lessThanOrEqualTo(20),
          reason: '${preset.id} tints too much',
        );
        expect(
          adjustment.contrast,
          lessThanOrEqualTo(40),
          reason: '${preset.id} crushes skin shadows',
        );
        expect(
          adjustment.saturation,
          inInclusiveRange(-100, 12),
          reason: '${preset.id} is oversaturated',
        );
      }
    });

    test('strength blends to neutral linearly', () {
      final half = LookLibrary.warm.asAdjustment(0.5);
      final full = LookLibrary.warm.asAdjustment(1);
      expect(half.temperature, closeTo(full.temperature / 2, 1e-9));
      expect(half.saturation, closeTo(full.saturation / 2, 1e-9));
      expect(LookLibrary.warm.asAdjustment(0).isNeutral, isTrue);
    });

    test('a channel mix is blended to identity by strength', () {
      final full = LookLibrary.film.channelMixAt(1)!;
      expect(full, LookLibrary.film.channelMix);
      final zero = LookLibrary.film.channelMixAt(0);
      expect(zero, isNull);
      final half = LookLibrary.film.channelMixAt(0.5)!;
      expect(half[0], closeTo((1 + full[0]) / 2, 1e-9));
      expect(LookLibrary.asIs.channelMixAt(1), isNull);
    });

    test(
      'an unknown id resolves to the plain scalars (read stays permissive)',
      () {
        final resolved = LookLibrary.resolve(
          const PhotoAdjustment(
            exposure: 0.5,
            look: LookSetting(id: 'from-the-future', strength: 1),
          ),
        );
        expect(resolved.exposure, 0.5);
        expect(resolved.channelMix, isNull);
        expect(LookLibrary.byId('from-the-future'), isNull);
      },
    );
  });

  group('look commands', () {
    test('SetLook rejects an id outside the allowlist', () {
      final document = tenPhotoProject();
      final result = const SetLook(
        photoId: 'p0',
        look: LookSetting(id: 'warm-film-v3', strength: 0.5),
      ).validate(document);
      expect(result, isA<CommandFailed>());
      expect(result.error!.code, CommandErrorCode.invalidValue);
      expect(result.error!.args['lookId'], 'warm-film-v3');
      expect(result.error!.args['allowed'], contains('warm'));
    });

    test('ApplyLook rejects an unknown id and an out-of-range strength', () {
      final document = tenPhotoProject();
      expect(
        const ApplyLook(
          photoIds: <String>['p0'],
          lookId: 'nope',
          strength: 0.5,
        ).validate(document).error!.code,
        CommandErrorCode.invalidValue,
      );
      expect(
        const ApplyLook(
          photoIds: <String>['p0'],
          lookId: 'warm',
          strength: 2,
        ).validate(document).error!.code,
        CommandErrorCode.invalidValue,
      );
      expect(
        const ApplyLook(
          photoIds: <String>['p0'],
          lookId: 'warm',
          strength: 0.5,
        ).validate(document),
        isA<CommandOk>(),
      );
    });

    test('strength is clamped to 0..1 on apply', () {
      final document = tenPhotoProject();
      final clamped = const LookSetting(
        id: 'warm',
        strength: 1,
      ).copyWith(strength: 1.4);
      expect(clamped.strength, 1);
      final applied = SetLook(photoId: 'p0', look: clamped).apply(document);
      expect(applied.photoAdjustments['p0']!.look!.strength, 1);
    });

    test('strength 0 stores no look at all', () {
      final edited = const ApplyLook(
        photoIds: <String>['p0'],
        lookId: 'warm',
        strength: 0,
      ).apply(tenPhotoProject());
      expect(edited.photoAdjustments, isEmpty);
    });

    test('ApplyLook is one undo step and restores the exact document', () {
      final document = tenPhotoProject();
      final stack = UndoStack(document: document);
      stack.execute(
        ApplyLook(
          photoIds: document.assets.map((asset) => asset.id).toList(),
          lookId: 'mono',
          strength: 0.8,
        ),
      );
      expect(stack.document.photoAdjustments.keys, hasLength(10));
      expect(stack.undoDepth, 1);
      expect(stack.undo(), isTrue);
      expect(stack.document, document);
    });
  });
}
