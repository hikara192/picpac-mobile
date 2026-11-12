import 'package:design_core/design_core.dart';
import 'package:test/test.dart';

void main() {
  group('AdjustmentMatrix', () {
    test('a neutral stack is the identity', () {
      expect(
        AdjustmentMatrix.encoded(PhotoAdjustment.neutral),
        AdjustmentMatrix.identity,
      );
      expect(
        AdjustmentMatrix.linear(PhotoAdjustment.neutral),
        AdjustmentMatrix.identity,
      );
    });

    test('a look at strength zero is the identity', () {
      final matrix = AdjustmentMatrix.encoded(
        const PhotoAdjustment(look: LookSetting(id: 'mono', strength: 0)),
      );
      expect(AdjustmentMatrix.isIdentity(matrix), isTrue);
    });

    test('an unknown look id is the identity (read stays permissive)', () {
      final matrix = AdjustmentMatrix.encoded(
        const PhotoAdjustment(
          look: LookSetting(id: 'from-the-future', strength: 1),
        ),
      );
      expect(AdjustmentMatrix.isIdentity(matrix), isTrue);
    });

    test('+1 EV is a gain of two in both domains', () {
      for (final matrix in <List<double>>[
        AdjustmentMatrix.encoded(const PhotoAdjustment(exposure: 1)),
        AdjustmentMatrix.linear(const PhotoAdjustment(exposure: 1)),
      ]) {
        expect(matrix[0], closeTo(2, 1e-12));
        expect(matrix[6], closeTo(2, 1e-12));
        expect(matrix[12], closeTo(2, 1e-12));
        expect(matrix[4], 0);
      }
    });

    test('full desaturation gives every channel the same luma mix', () {
      final matrix = AdjustmentMatrix.encoded(
        const PhotoAdjustment(saturation: -100),
      );
      for (var row = 0; row < 3; row++) {
        for (var column = 0; column < 3; column++) {
          expect(
            matrix[row * 5 + column],
            closeTo(AdjustmentMatrix.lumaWeights[column], 1e-12),
          );
        }
      }
    });

    test('the documented order is WB → exposure → contrast → saturation → look', () {
      const adjustment = PhotoAdjustment(exposure: 1, contrast: 50);
      final composed = AdjustmentMatrix.encoded(adjustment);
      final expected = AdjustmentMatrix.multiply(
        AdjustmentMatrix.encoded(const PhotoAdjustment(contrast: 50)),
        AdjustmentMatrix.encoded(const PhotoAdjustment(exposure: 1)),
      );
      for (var i = 0; i < 20; i++) {
        expect(composed[i], closeTo(expected[i], 1e-9), reason: 'entry $i');
      }
    });

    test('saturation is exact in both domains, contrast is not', () {
      const saturation = PhotoAdjustment(saturation: 40);
      expect(
        AdjustmentMatrix.encoded(saturation),
        AdjustmentMatrix.linear(saturation),
      );
      final encodedContrast = AdjustmentMatrix.encoded(
        const PhotoAdjustment(contrast: 40),
      );
      final linearContrast = AdjustmentMatrix.linear(
        const PhotoAdjustment(contrast: 40),
      );
      expect(encodedContrast[0], closeTo(linearContrast[0], 1e-12));
      expect(
        encodedContrast[4],
        isNot(closeTo(linearContrast[4], 1e-6)),
        reason: 'offsets live in 0..255 vs 0..1',
      );
    });

    test('extreme but legal values stay finite', () {
      final extreme = PhotoAdjustment(
        exposure: AdjustmentLimits.exposure.max,
        contrast: AdjustmentLimits.contrast.max,
        temperature: AdjustmentLimits.temperature.max,
        tint: AdjustmentLimits.tint.min,
        saturation: AdjustmentLimits.saturation.min,
        vibrance: AdjustmentLimits.vibrance.max,
        look: const LookSetting(id: 'film', strength: 1),
      );
      for (final matrix in <List<double>>[
        AdjustmentMatrix.encoded(extreme),
        AdjustmentMatrix.linear(extreme),
      ]) {
        expect(matrix, hasLength(20));
        for (final value in matrix) {
          expect(value.isFinite, isTrue);
        }
      }
    });

    test('multiplying by the identity changes nothing', () {
      final matrix = AdjustmentMatrix.encoded(
        const PhotoAdjustment(temperature: 20, saturation: -15),
      );
      final roundTrip = AdjustmentMatrix.multiply(
        AdjustmentMatrix.identity,
        matrix,
      );
      for (var i = 0; i < 20; i++) {
        expect(roundTrip[i], closeTo(matrix[i], 1e-12));
      }
    });
  });

  group('adjustment limits', () {
    test('every field has one documented range and the command uses it', () {
      for (final field in PhotoAdjustmentField.values) {
        final limit = AdjustmentLimits.of(field);
        expect(limit.field, field);
        expect(limit.min, lessThan(limit.max));
        expect(limit.step, greaterThan(0));
        expect(limit.id, field.wire);
        expect(field.min, limit.min);
        expect(field.max, limit.max);
      }
      expect(AdjustmentLimits.all, hasLength(7));
      expect(AdjustmentLimits.lookStrength.min, 0);
      expect(AdjustmentLimits.lookStrength.max, 1);
    });

    test('a slider can only produce skin-safe values', () {
      expect(AdjustmentLimits.exposure.uiLower, -1);
      expect(AdjustmentLimits.contrast.uiUpper, 40);
      expect(AdjustmentLimits.saturation.uiUpper, 25);
      expect(AdjustmentLimits.saturation.uiLower, -30);
      expect(AdjustmentLimits.temperature.uiUpper, 50);
      expect(AdjustmentLimits.vibrance.uiExposed, isFalse);
      expect(AdjustmentLimits.tint.uiExposed, isFalse);
    });

    test('clamp and snap are total functions', () {
      final exposure = AdjustmentLimits.exposure;
      expect(exposure.clamp(9), 2);
      expect(exposure.clamp(-9), -2);
      expect(exposure.clamp(double.nan), 0);
      expect(exposure.clamp(double.infinity), 2);
      expect(exposure.clamp(double.negativeInfinity), -2);
      expect(exposure.snap(0.3333), closeTo(0.35, 1e-9));
      expect(exposure.uiClamp(1.5), 1);
    });

    test('SetPhotoAdjustment stores the clamped value', () {
      final document = DesignDocument(
        product: const DocumentProduct(id: 'photo_print', formatId: '10x15'),
        assets: <PhotoAsset>[
          PhotoAsset(
            id: 'p0',
            sha256: 'a' * 64,
            widthPx: 100,
            heightPx: 100,
            mimeType: 'image/jpeg',
            bytes: 10,
          ),
        ],
      );
      final after = const SetPhotoAdjustment(
        photoId: 'p0',
        field: PhotoAdjustmentField.exposure,
        value: 99,
      ).apply(document);
      expect(after.photoAdjustments['p0']!.exposure, 2);
    });
  });
}
