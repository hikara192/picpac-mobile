import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:design_core/design_core.dart';
import 'package:flutter/services.dart';

import 'photo_format.dart';

enum NormalizationAction {
  copy,

  reencode,

  reject,
}

final class NormalizationDecision {
  const NormalizationDecision._({
    required this.action,
    required this.sourceMime,
    required this.outputMime,
    this.rejection,
  });

  const NormalizationDecision.copy({
    required String sourceMime,
    required String outputMime,
  }) : this._(
         action: NormalizationAction.copy,
         sourceMime: sourceMime,
         outputMime: outputMime,
       );

  const NormalizationDecision.reencode({
    required String sourceMime,
    required String outputMime,
  }) : this._(
         action: NormalizationAction.reencode,
         sourceMime: sourceMime,
         outputMime: outputMime,
       );

  const NormalizationDecision.reject(MediaFailure rejection)
    : this._(
        action: NormalizationAction.reject,
        sourceMime: '',
        outputMime: '',
        rejection: rejection,
      );

  final NormalizationAction action;

  final String sourceMime;

  final String outputMime;

  final MediaFailure? rejection;

  bool get isCopy => action == NormalizationAction.copy;

  bool get isRejected => action == NormalizationAction.reject;
}

abstract final class NormalizationPolicy {
  static NormalizationDecision decide({
    required String sourceMime,
    required int bytes,
    bool pngCarriesMetadata = false,
  }) {
    final mime = PhotoFormats.normalizeMime(sourceMime);
    if (bytes > PhotoFormats.maxSourceBytes) {
      return NormalizationDecision.reject(
        MediaFailure(
          code: MediaErrorCode.tooLarge,
          message: 'the source file exceeds the import budget',
          args: <String, Object?>{'limit': PhotoFormats.maxSourceMegabytes},
        ),
      );
    }
    if (bytes <= 0) {
      return const NormalizationDecision.reject(
        MediaFailure(
          code: MediaErrorCode.decodeFailed,
          message: 'the source file is empty',
        ),
      );
    }
    if (mime == PhotoFormats.jpeg) {
      return const NormalizationDecision.reencode(
        sourceMime: PhotoFormats.jpeg,
        outputMime: PhotoFormats.jpeg,
      );
    }
    if (mime == PhotoFormats.png) {
      return pngCarriesMetadata
          ? const NormalizationDecision.reencode(
              sourceMime: PhotoFormats.png,
              outputMime: PhotoFormats.png,
            )
          : const NormalizationDecision.copy(
              sourceMime: PhotoFormats.png,
              outputMime: PhotoFormats.png,
            );
    }
    if (PhotoFormats.needsConversion(mime)) {
      return NormalizationDecision.reencode(
        sourceMime: mime,
        outputMime: PhotoFormats.jpeg,
      );
    }
    return const NormalizationDecision.reject(
      MediaFailure(
        code: MediaErrorCode.unsupportedFormat,
        message: 'only JPEG, PNG and HEIC/HEIF photos are printable',
      ),
    );
  }
}

final class NormalizedPhoto {
  const NormalizedPhoto({
    required this.file,
    required this.mimeType,
    required this.sourceMime,
    required this.widthPx,
    required this.heightPx,
    required this.bytes,
    required this.sha256,
    required this.converted,
  });

  final File file;

  final String mimeType;

  final String sourceMime;

  final int widthPx;

  final int heightPx;

  final int bytes;

  final String sha256;

  final bool converted;

  @override
  String toString() =>
      'NormalizedPhoto($mimeType ${widthPx}x$heightPx, $bytes B, '
      'converted: $converted)';
}

abstract interface class PhotoNormalizerPort {
  Future<Result<NormalizedPhoto>> normalize({
    required File source,
    required File output,
    required String sourceMime,
    required String outputMime,
    int quality = PhotoFormats.jpegQuality,
    int maxPixels = PhotoFormats.maxOutputPixels,
  });
}

final class PlatformPhotoNormalizer implements PhotoNormalizerPort {
  const PlatformPhotoNormalizer({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'by.picpac/media';

  final MethodChannel _channel;

  @override
  Future<Result<NormalizedPhoto>> normalize({
    required File source,
    required File output,
    required String sourceMime,
    required String outputMime,
    int quality = PhotoFormats.jpegQuality,
    int maxPixels = PhotoFormats.maxOutputPixels,
  }) async {
    Map<String, Object?>? response;
    try {
      response = await _channel.invokeMapMethod<String, Object?>('normalize', {
        'sourcePath': source.path,
        'outputPath': output.path,
        'sourceMime': sourceMime,
        'outputMime': outputMime,
        'quality': quality,
        'maxPixels': maxPixels,
      });
    } on PlatformException catch (error) {
      return Err<NormalizedPhoto>(_mapPlatformError(error));
    } on MissingPluginException {
      return const Err<NormalizedPhoto>(
        MediaFailure(
          code: MediaErrorCode.conversionFailed,
          message: 'no media normaliser is registered on this platform',
        ),
      );
    } on Object catch (error) {
      return Err<NormalizedPhoto>(
        MediaFailure(
          code: MediaErrorCode.conversionFailed,
          message: 'the media channel failed: ${error.runtimeType}',
        ),
      );
    }
    if (response == null) {
      return const Err<NormalizedPhoto>(
        MediaFailure(
          code: MediaErrorCode.conversionFailed,
          message: 'the media channel returned no payload',
        ),
      );
    }
    return _toNormalized(response, fallbackSourceMime: sourceMime);
  }

  Future<Result<NormalizedPhoto>> _toNormalized(
    Map<String, Object?> response, {
    required String fallbackSourceMime,
  }) async {
    final path = response['path'];
    final width = _asInt(response['widthPx']);
    final height = _asInt(response['heightPx']);
    final bytes = _asInt(response['bytes']);
    if (path is! String || width <= 0 || height <= 0 || bytes <= 0) {
      return const Err<NormalizedPhoto>(
        MediaFailure(
          code: MediaErrorCode.conversionFailed,
          message: 'the normaliser returned an unusable payload',
        ),
      );
    }
    final file = File(path);
    final reportedHash = response['sha256'];
    final digest = reportedHash is String && reportedHash.length == 64
        ? reportedHash.toLowerCase()
        : await sha256File(file);
    return Ok<NormalizedPhoto>(
      NormalizedPhoto(
        file: file,
        mimeType: PhotoFormats.normalizeMime(
          response['mimeType'] as String? ?? '',
        ),
        sourceMime: PhotoFormats.normalizeMime(
          response['sourceMime'] as String? ?? fallbackSourceMime,
        ),
        widthPx: width,
        heightPx: height,
        bytes: bytes,
        sha256: digest,
        converted: response['converted'] != false,
      ),
    );
  }

  static int _asInt(Object? value) => switch (value) {
    final int v => v,
    final num v => v.toInt(),
    _ => 0,
  };

  static MediaFailure _mapPlatformError(PlatformException error) {
    final code = switch (error.code) {
      'unsupported_format' => MediaErrorCode.unsupportedFormat,
      'too_large' => MediaErrorCode.tooLarge,
      'out_of_memory' => MediaErrorCode.outOfMemory,
      'permission_denied' => MediaErrorCode.permissionDenied,
      'decode_failed' => MediaErrorCode.decodeFailed,
      _ => MediaErrorCode.conversionFailed,
    };
    return MediaFailure(
      code: code,
      message: error.message ?? 'the platform normaliser failed',
      args: <String, Object?>{'platform': error.code},
    );
  }
}

Future<String> sha256File(File file) async {
  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString();
}
