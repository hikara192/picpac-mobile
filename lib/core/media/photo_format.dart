library;

import 'package:design_core/design_core.dart';

abstract final class PhotoFormats {
  static const String jpeg = 'image/jpeg';

  static const String png = 'image/png';

  static const String heic = 'image/heic';

  static const String heif = 'image/heif';

  static const String avif = 'image/avif';

  static const String webp = 'image/webp';

  static const Set<String> printable = <String>{jpeg, png};

  static const Set<String> convertible = <String>{heic, heif};

  static const int maxSourceBytes = 50 * 1024 * 1024;

  static const int maxBytes = 25 * 1024 * 1024;

  static const int minSidePx = 200;

  static const int previewMaxSide = 2048;

  static const int maxOutputPixels = 20000000;

  static const int lowMemoryOutputPixels = 12000000;

  static const int jpegQuality = 95;

  static const int headerBytes = 32;

  static int get maxMegabytes => maxBytes ~/ (1024 * 1024);

  static int get maxSourceMegabytes => maxSourceBytes ~/ (1024 * 1024);

  static String normalizeMime(String? raw) {
    if (raw == null) return '';
    final value = raw.split(';').first.trim().toLowerCase();
    return switch (value) {
      'image/jpg' || 'image/pjpeg' => jpeg,
      'image/x-png' => png,
      'image/heic-sequence' || 'image/heif-sequence' => heic,
      _ => value,
    };
  }

  static bool isPrintable(String? mime) =>
      printable.contains(normalizeMime(mime));

  static bool needsConversion(String? mime) =>
      convertible.contains(normalizeMime(mime));

  static String fromFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '';
    final extension = fileName.substring(dot + 1).toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' || 'jpe' || 'jfif' => jpeg,
      'png' => png,
      'heic' || 'heif' => heic,
      'avif' => avif,
      'webp' => webp,
      _ => '',
    };
  }
}

enum PhotoRejectionCode {
  heicUnsupported('heic_unsupported'),

  unsupportedFormat('unsupported_format'),

  tooLarge('too_large'),

  tooSmall('too_small'),

  unreadable('unreadable'),

  duplicate('duplicate');

  const PhotoRejectionCode(this.wire);

  final String wire;
}

final class PhotoRejection {
  const PhotoRejection({
    required this.code,
    required this.fileName,
    this.args = const <String, Object?>{},
  });

  final PhotoRejectionCode code;

  final String fileName;

  final Map<String, Object?> args;

  @override
  String toString() => 'PhotoRejection(${code.wire}, $fileName, $args)';
}

final class MediaFailure implements Failure {
  const MediaFailure({
    required this.code,
    required this.message,
    this.args = const <String, Object?>{},
  });

  factory MediaFailure.permissionDenied() => const MediaFailure(
    code: MediaErrorCode.permissionDenied,
    message: 'photo library access was denied',
  );

  factory MediaFailure.pickerUnavailable({String? message}) => MediaFailure(
    code: MediaErrorCode.pickerUnavailable,
    message: message ?? 'the photo picker is unavailable',
  );

  @override
  final String code;

  @override
  final String message;

  @override
  final Map<String, Object?> args;

  @override
  String toString() => 'MediaFailure($code): $message';
}

abstract final class MediaErrorCode {
  static const String permissionDenied = 'media_permission_denied';

  static const String pickerUnavailable = 'media_picker_unavailable';

  static const String decodeFailed = 'media_decode_failed';

  static const String unsupportedFormat = 'media_unsupported_format';

  static const String conversionFailed = 'media_conversion_failed';

  static const String tooLarge = 'media_too_large';

  static const String tooSmall = 'media_too_small';

  static const String outOfMemory = 'media_out_of_memory';

  static const String cacheFailed = 'media_cache_failed';

  static const String duplicateContent = 'media_duplicate_content';
}
