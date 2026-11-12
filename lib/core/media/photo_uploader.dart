import 'package:api_contract/api_contract.dart';

import '../app_logger.dart';
import 'photo_importer.dart';
import 'photo_storage.dart';

enum PhotoUploadStage {
  queued('queued'),

  presigning('presigning'),

  transferring('transferring'),

  confirming('confirming'),

  completed('completed'),

  failed('failed');

  const PhotoUploadStage(this.wire);

  final String wire;

  bool get isActive =>
      this == presigning || this == transferring || this == confirming;
}

final class PhotoUploader {
  PhotoUploader({
    required this._api,
    required this._storage,
    this._logger = const AppLogger(),
  });

  final ApiPort _api;
  final PhotoStoragePort _storage;
  final AppLogger _logger;

  Future<Result<CompletedUpload>> upload(
    PreparedPhoto photo, {
    void Function(PhotoUploadStage stage)? onStage,
    void Function(double progress)? onProgress,
  }) async {
    onStage?.call(PhotoUploadStage.presigning);
    final presigned = await _api.presignUpload(
      PresignUploadRequest(
        fileName: photo.fileName,
        mimeType: photo.mimeType,
        bytes: photo.bytes,
        sha256: photo.sha256,
      ),
    );
    if (presigned case Err<UploadTicket>(:final error)) {
      _logFailure('presign', error);
      return Err<CompletedUpload>(error);
    }
    final ticket = (presigned as Ok<UploadTicket>).value;

    onStage?.call(PhotoUploadStage.transferring);
    final transferred = await _storage.putObject(
      ticket: ticket,
      file: photo.cachedFile,
      onProgress: (sent, total) {
        if (total <= 0) return;
        onProgress?.call((sent / total).clamp(0, 1).toDouble());
      },
    );
    if (transferred case Err<void>(:final error)) {
      _logFailure('transfer', error);
      return Err<CompletedUpload>(error);
    }

    onStage?.call(PhotoUploadStage.confirming);
    final confirmed = await _api.completeUpload(
      uploadId: ticket.uploadId,
      sha256: photo.sha256,
    );
    if (confirmed case Err<CompletedUpload>(:final error)) {
      _logFailure('complete', error);
      return Err<CompletedUpload>(error);
    }
    onStage?.call(PhotoUploadStage.completed);
    _logger.debug('media.upload.done', <String, Object?>{
      'bytes': photo.bytes,
      'mime': photo.mimeType,
    });
    return confirmed;
  }

  void _logFailure(String step, Failure failure) {
    _logger.warning('media.upload.$step.failed', <String, Object?>{
      'code': failure.code,
    });
  }
}
