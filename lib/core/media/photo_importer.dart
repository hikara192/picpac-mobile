import 'dart:io';

import 'package:design_core/design_core.dart';

import '../app_logger.dart';
import 'asset_cache.dart';
import 'image_probe.dart';
import 'mime_sniffer.dart';
import 'photo_format.dart';
import 'photo_normalizer.dart';
import 'photo_picker.dart';

final class PreparedPhoto {
  const PreparedPhoto({
    required this.cachedFile,
    required this.sha256,
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    required this.widthPx,
    required this.heightPx,
  });

  final File cachedFile;

  final String sha256;

  final String fileName;

  final String mimeType;

  final int bytes;

  final int widthPx;

  final int heightPx;

  PhotoAsset toAsset(String id) => PhotoAsset(
    id: id,
    sha256: sha256,
    widthPx: widthPx,
    heightPx: heightPx,
    mimeType: mimeType,
    bytes: bytes,
  );
}

final class PhotoImportBatch {
  const PhotoImportBatch({
    this.prepared = const <PreparedPhoto>[],
    this.rejections = const <PhotoRejection>[],
    this.duplicates = 0,
  });

  final List<PreparedPhoto> prepared;

  final List<PhotoRejection> rejections;

  final int duplicates;

  bool get isEmpty => prepared.isEmpty && rejections.isEmpty && duplicates == 0;
}

final class PhotoImporter {
  PhotoImporter({
    required this._picker,
    required this._cache,
    required this._probe,
    PhotoNormalizerPort? normalizer,
    this._logger = const AppLogger(),
  }) : _normalizer = normalizer ?? const PlatformPhotoNormalizer();

  final PhotoPickerPort _picker;
  final DesignAssetCache _cache;
  final ImageProbePort _probe;
  final PhotoNormalizerPort _normalizer;
  final AppLogger _logger;

  int _sequence = 0;

  Future<Result<PhotoImportBatch>> pickAndPrepare({
    required String designId,
    Iterable<String> knownHashes = const <String>[],
    int? limit,
  }) async {
    final picked = await _picker.pickImages(limit: limit);
    return switch (picked) {
      Err<List<PickedFile>>(:final error) => Err<PhotoImportBatch>(error),
      Ok<List<PickedFile>>(:final value) => Ok<PhotoImportBatch>(
        await prepare(
          designId: designId,
          files: value,
          knownHashes: knownHashes,
          limit: limit,
        ),
      ),
    };
  }

  Future<PhotoImportBatch> prepare({
    required String designId,
    required List<PickedFile> files,
    Iterable<String> knownHashes = const <String>[],
    int? limit,
  }) async {
    final seen = knownHashes.map((hash) => hash.toLowerCase()).toSet();
    final prepared = <PreparedPhoto>[];
    final rejections = <PhotoRejection>[];
    var duplicates = 0;

    Directory? scratch;
    Future<Directory> scratchDirectory() async =>
        scratch ??= await Directory.systemTemp.createTemp('picpac_media_');
    try {
      for (final file in files) {
        if (limit != null && prepared.length >= limit) {
          break;
        }
        final attempt = await _prepareOne(
          designId: designId,
          file: file,
          seen: seen,
          scratchDirectory: scratchDirectory,
        );
        switch (attempt) {
          case _Prepared(:final photo):
            seen.add(photo.sha256);
            prepared.add(photo);
          case _Duplicate():
            duplicates++;
          case _Rejected(:final failure, :final sourceMime):
            rejections.add(
              PhotoRejection(
                code: _rejectionCodeFor(failure, sourceMime),
                fileName: file.name,
                args: failure.args,
              ),
            );
        }
      }
    } finally {
      final directory = scratch;
      if (directory != null) {
        try {
          await directory.delete(recursive: true);
        } on Object {
        }
      }
    }

    _logger.debug('media.import', <String, Object?>{
      'prepared': prepared.length,
      'rejected': rejections.length,
      'duplicates': duplicates,
      'codes': <String>[for (final r in rejections) r.code.wire],
    });
    return PhotoImportBatch(
      prepared: prepared,
      rejections: rejections,
      duplicates: duplicates,
    );
  }

  Future<_Attempt> _prepareOne({
    required String designId,
    required PickedFile file,
    required Set<String> seen,
    required Future<Directory> Function() scratchDirectory,
  }) async {
    final source = File(file.path);
    final size = await _lengthOf(source) ?? file.bytes;

    if (size > PhotoFormats.maxSourceBytes) {
      return _Rejected(
        failure: MediaFailure(
          code: MediaErrorCode.tooLarge,
          message: 'the source file exceeds the import budget',
          args: <String, Object?>{'limit': PhotoFormats.maxSourceMegabytes},
        ),
        sourceMime: '',
      );
    }

    final sourceMime = await MimeSniffer.detectFile(source);
    if (sourceMime.isEmpty) {
      return const _Rejected(
        failure: MediaFailure(
          code: MediaErrorCode.unsupportedFormat,
          message: 'the file header matches no supported photo format',
        ),
        sourceMime: '',
      );
    }

    final decision = NormalizationPolicy.decide(
      sourceMime: sourceMime,
      bytes: size,
      pngCarriesMetadata:
          sourceMime == PhotoFormats.png && await pngHasMetadata(source),
    );
    if (decision.isRejected) {
      return _Rejected(failure: decision.rejection!, sourceMime: sourceMime);
    }

    return decision.isCopy
        ? _copyThrough(
            designId: designId,
            file: file,
            source: source,
            sourceMime: sourceMime,
            bytes: size,
            seen: seen,
          )
        : _convertThrough(
            designId: designId,
            file: file,
            source: source,
            scratchDirectory: scratchDirectory,
            decision: decision,
            seen: seen,
          );
  }

  Future<_Attempt> _copyThrough({
    required String designId,
    required PickedFile file,
    required File source,
    required String sourceMime,
    required int bytes,
    required Set<String> seen,
  }) async {
    String digest;
    try {
      digest = await sha256File(source);
    } on Object catch (error) {
      return _Rejected(
        failure: MediaFailure(
          code: MediaErrorCode.decodeFailed,
          message: 'the file cannot be read: ${error.runtimeType}',
        ),
        sourceMime: sourceMime,
      );
    }
    if (seen.contains(digest)) {
      return _Duplicate(sourceMime);
    }

    final measured = await _probe.probe(source);
    if (measured case Err<ProbedPhoto>(:final error)) {
      return _Rejected(failure: error, sourceMime: sourceMime);
    }
    final geometry = (measured as Ok<ProbedPhoto>).value;

    final cached = await _cache.store(
      designId: designId,
      sha256: digest,
      source: source,
    );
    return switch (cached) {
      Err<File>(:final error) => _Rejected(
        failure: error,
        sourceMime: sourceMime,
      ),
      Ok<File>(:final value) => _Prepared(
        PreparedPhoto(
          cachedFile: value,
          sha256: digest,
          fileName: file.name,
          mimeType: PhotoFormats.png,
          bytes: bytes,
          widthPx: geometry.widthPx,
          heightPx: geometry.heightPx,
        ),
      ),
    };
  }

  Future<_Attempt> _convertThrough({
    required String designId,
    required PickedFile file,
    required File source,
    required Future<Directory> Function() scratchDirectory,
    required NormalizationDecision decision,
    required Set<String> seen,
  }) async {
    final scratch = await scratchDirectory();
    final output = File(
      '${scratch.path}/normalized_${_sequence++}.'
      '${_extensionFor(decision.outputMime)}',
    );
    final normalized = await _normalizer.normalize(
      source: source,
      output: output,
      sourceMime: decision.sourceMime,
      outputMime: decision.outputMime,
    );
    try {
      switch (normalized) {
        case Err<NormalizedPhoto>(:final error):
          return _Rejected(failure: error, sourceMime: decision.sourceMime);
        case Ok<NormalizedPhoto>(:final value):
          return await _accept(
            designId: designId,
            file: file,
            normalized: value,
            decision: decision,
            seen: seen,
          );
      }
    } finally {
      try {
        if (await output.exists()) await output.delete();
      } on Object {
      }
    }
  }

  Future<_Attempt> _accept({
    required String designId,
    required PickedFile file,
    required NormalizedPhoto normalized,
    required NormalizationDecision decision,
    required Set<String> seen,
  }) async {
    final written = await _lengthOf(normalized.file);
    if (written == null || written != normalized.bytes) {
      return _Rejected(
        failure: MediaFailure(
          code: MediaErrorCode.conversionFailed,
          message: 'the normalised file does not match its reported size',
        ),
        sourceMime: decision.sourceMime,
      );
    }
    if (normalized.bytes > PhotoFormats.maxBytes) {
      return _Rejected(
        failure: MediaFailure(
          code: MediaErrorCode.tooLarge,
          message: 'the normalised photo exceeds the upload budget',
          args: <String, Object?>{'limit': PhotoFormats.maxMegabytes},
        ),
        sourceMime: decision.sourceMime,
      );
    }
    if (seen.contains(normalized.sha256)) {
      return _Duplicate(decision.sourceMime);
    }

    final measured = await _probe.probe(normalized.file);
    final geometry = switch (measured) {
      Ok<ProbedPhoto>(:final value) => value,
      Err<ProbedPhoto>() => ProbedPhoto(
        widthPx: normalized.widthPx,
        heightPx: normalized.heightPx,
      ),
    };
    if (geometry.widthPx < PhotoFormats.minSidePx ||
        geometry.heightPx < PhotoFormats.minSidePx) {
      return _Rejected(
        failure: MediaFailure(
          code: MediaErrorCode.tooSmall,
          message: 'the photo is below the printable minimum',
          args: <String, Object?>{
            'width': geometry.widthPx,
            'height': geometry.heightPx,
          },
        ),
        sourceMime: decision.sourceMime,
      );
    }

    final cached = await _cache.store(
      designId: designId,
      sha256: normalized.sha256,
      source: normalized.file,
    );
    return switch (cached) {
      Err<File>(:final error) => _Rejected(
        failure: error,
        sourceMime: decision.sourceMime,
      ),
      Ok<File>(:final value) => _Prepared(
        PreparedPhoto(
          cachedFile: value,
          sha256: normalized.sha256,
          fileName: file.name,
          mimeType: normalized.mimeType.isEmpty
              ? decision.outputMime
              : normalized.mimeType,
          bytes: normalized.bytes,
          widthPx: geometry.widthPx,
          heightPx: geometry.heightPx,
        ),
      ),
    };
  }

  Future<int?> _lengthOf(File file) async {
    try {
      return await file.length();
    } on Object {
      return null;
    }
  }

  static String _extensionFor(String mimeType) =>
      mimeType == PhotoFormats.png ? 'png' : 'jpg';

  PhotoRejectionCode _rejectionCodeFor(Failure failure, String sourceMime) {
    final heifSource = PhotoFormats.needsConversion(sourceMime);
    return switch (failure.code) {
      MediaErrorCode.unsupportedFormat => PhotoRejectionCode.unsupportedFormat,
      MediaErrorCode.tooLarge => PhotoRejectionCode.tooLarge,
      MediaErrorCode.tooSmall => PhotoRejectionCode.tooSmall,
      MediaErrorCode.outOfMemory ||
      MediaErrorCode.conversionFailed ||
      MediaErrorCode.decodeFailed =>
        heifSource
            ? PhotoRejectionCode.heicUnsupported
            : PhotoRejectionCode.unreadable,
      _ => PhotoRejectionCode.unreadable,
    };
  }
}

sealed class _Attempt {
  const _Attempt();
}

final class _Prepared extends _Attempt {
  const _Prepared(this.photo);

  final PreparedPhoto photo;
}

final class _Duplicate extends _Attempt {
  const _Duplicate(this.sourceMime);

  final String sourceMime;
}

final class _Rejected extends _Attempt {
  const _Rejected({required this.failure, required this.sourceMime});

  final Failure failure;
  final String sourceMime;
}
