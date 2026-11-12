import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/core/media/photo_format.dart';
import 'package:picpac_mobile/core/media/photo_normalizer.dart';

void main() {
  group('policy', () {
    test('HEIC is converted, not refused', () {
      final decision = NormalizationPolicy.decide(
        sourceMime: PhotoFormats.heic,
        bytes: 3 * 1024 * 1024,
      );
      expect(decision.action, NormalizationAction.reencode);
      expect(decision.outputMime, PhotoFormats.jpeg);
      expect(decision.isRejected, isFalse);
    });

    test('HEIF is treated exactly like HEIC', () {
      final decision = NormalizationPolicy.decide(
        sourceMime: PhotoFormats.heif,
        bytes: 1024,
      );
      expect(decision.action, NormalizationAction.reencode);
      expect(decision.outputMime, PhotoFormats.jpeg);
    });

    test('JPEG is re-encoded even though it is already printable', () {
      final decision = NormalizationPolicy.decide(
        sourceMime: PhotoFormats.jpeg,
        bytes: 4 * 1024 * 1024,
      );
      expect(decision.action, NormalizationAction.reencode);
      expect(decision.outputMime, PhotoFormats.jpeg);
    });

    test('PNG without metadata is copied byte for byte', () {
      final decision = NormalizationPolicy.decide(
        sourceMime: PhotoFormats.png,
        bytes: 900 * 1024,
      );
      expect(decision.action, NormalizationAction.copy);
      expect(decision.outputMime, PhotoFormats.png);
      expect(decision.isCopy, isTrue);
    });

    test('PNG with eXIf or XMP is re-encoded to strip it', () {
      final decision = NormalizationPolicy.decide(
        sourceMime: PhotoFormats.png,
        bytes: 900 * 1024,
        pngCarriesMetadata: true,
      );
      expect(decision.action, NormalizationAction.reencode);
      expect(decision.outputMime, PhotoFormats.png);
    });

    test('AVIF, WebP and unknown bytes are refused with one code', () {
      for (final mime in <String>[
        PhotoFormats.avif,
        PhotoFormats.webp,
        'image/gif',
        'application/octet-stream',
        '',
      ]) {
        final decision = NormalizationPolicy.decide(
          sourceMime: mime,
          bytes: 1024,
        );
        expect(decision.action, NormalizationAction.reject, reason: mime);
        expect(
          decision.rejection!.code,
          MediaErrorCode.unsupportedFormat,
          reason: mime,
        );
      }
    });

    test('a file above the input budget is refused before decoding', () {
      final decision = NormalizationPolicy.decide(
        sourceMime: PhotoFormats.jpeg,
        bytes: PhotoFormats.maxSourceBytes + 1,
      );
      expect(decision.action, NormalizationAction.reject);
      expect(decision.rejection!.code, MediaErrorCode.tooLarge);
      expect(
        decision.rejection!.args['limit'],
        PhotoFormats.maxSourceMegabytes,
      );
    });

    test('an empty file is unreadable, not unsupported', () {
      final decision = NormalizationPolicy.decide(
        sourceMime: PhotoFormats.jpeg,
        bytes: 0,
      );
      expect(decision.action, NormalizationAction.reject);
      expect(decision.rejection!.code, MediaErrorCode.decodeFailed);
    });

    test('MIME aliases resolve before the decision', () {
      final decision = NormalizationPolicy.decide(
        sourceMime: 'image/jpg; charset=binary',
        bytes: 1024,
      );
      expect(decision.sourceMime, PhotoFormats.jpeg);
      expect(decision.action, NormalizationAction.reencode);
    });
  });

  group('limits', () {
    test('the pixel cap covers the largest catalogue format', () {
      const largestFormatPixels = 5398 * 3602;
      expect(largestFormatPixels, lessThan(PhotoFormats.maxOutputPixels));
      expect(PhotoFormats.maxOutputPixels, 20000000);
    });

    test(
      'the low-RAM budget is below the normal one but above the minimum',
      () {
        expect(
          PhotoFormats.lowMemoryOutputPixels,
          lessThan(PhotoFormats.maxOutputPixels),
        );
        expect(PhotoFormats.lowMemoryOutputPixels, greaterThan(4000000));
      },
    );

    test('the input budget is larger than the upload budget', () {
      expect(PhotoFormats.maxSourceBytes, greaterThan(PhotoFormats.maxBytes));
      expect(PhotoFormats.maxBytes, 25 * 1024 * 1024);
      expect(PhotoFormats.jpegQuality, 95);
    });
  });
}
