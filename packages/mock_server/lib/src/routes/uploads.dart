import 'dart:math' as math;

import 'package:api_contract/api_contract.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../context.dart';
import '../errors.dart';
import '../mock_server.dart';
import '../records.dart';

const int maxUploadBytes = 25 * 1024 * 1024;

const Set<String> allowedUploadMimeTypes = <String>{'image/jpeg', 'image/png'};

void registerUploadRoutes(Router router, MockServer server) {
  router.post('/v1/uploads/presign', (Request request) async {
    final ctx = contextOf(request);
    ctx.requireSession();
    final parsed = PresignUploadRequest.fromJson(await ctx.jsonBody());

    final mime = parsed.mimeType.trim().toLowerCase();
    if (!allowedUploadMimeTypes.contains(mime)) {
      throw ApiException(
        422,
        'unsupported_format',
        'only JPEG and PNG originals are accepted; HEIC conversion is not '
            'available in stage 0',
        fieldErrors: <String, String>{'mimeType': 'unsupported_format'},
      );
    }
    if (parsed.bytes <= 0 || parsed.bytes > maxUploadBytes) {
      throw ApiException.validation(
        'the upload size is outside the accepted range',
        fieldErrors: <String, String>{
          'bytes': parsed.bytes <= 0 ? 'too_small' : 'too_large',
        },
      );
    }
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(parsed.sha256.toLowerCase())) {
      throw ApiException.validation(
        'sha256 must be a lower-case hex digest',
        fieldErrors: const <String, String>{'sha256': 'invalid_sha256'},
      );
    }

    final now = server.clock.now();
    final id = 'upl_${const Uuid().v4()}';
    final record = UploadRecord(
      id: id,
      ownerId: ctx.session!.customerId,
      fileName: _safeFileName(parsed.fileName),
      mimeType: mime,
      bytes: parsed.bytes,
      sha256: parsed.sha256.toLowerCase(),
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 15)),
    );
    server.uploads[id] = record;
    ctx.audit(
      action: 'upload.presign',
      objectType: 'upload',
      objectId: id,
      details: <String, Object?>{'mimeType': mime, 'bytes': parsed.bytes},
    );

    return ctx.json(
      UploadTicket(
        uploadId: id,
        url: '${ctx.origin}/v1/mock/uploads/$id',
        method: 'PUT',
        headers: <String, String>{
          'content-type': mime,
          'x-content-sha256': record.sha256,
        },
        expiresAt: record.expiresAt,
        maxBytes: maxUploadBytes,
      ).toJson(),
    );
  });

  router.put('/v1/mock/uploads/<uploadId>', (
    Request request,
    String uploadId,
  ) async {
    final ctx = contextOf(request);
    final record = _uploadById(server, uploadId);
    if (record.completed) {
      throw ApiException.conflict(
        'upload_already_completed',
        'the upload is already completed',
      );
    }
    if (record.isExpiredAt(server.clock.now())) {
      throw ApiException(
        410,
        'upload_expired',
        'the upload ticket has expired',
      );
    }
    final contentType = ctx.header('content-type')?.split(';').first.trim();
    if (contentType != null &&
        contentType.isNotEmpty &&
        contentType.toLowerCase() != record.mimeType) {
      throw ApiException.validation(
        'content-type does not match the presigned ticket',
        fieldErrors: const <String, String>{'content-type': 'mime_mismatch'},
      );
    }

    final ({int bytes, String sha256, List<int> prefix}) received;
    try {
      received = await ctx.readVerifiableBinary(maxBytes: record.bytes);
    } on ApiException catch (error) {
      if (error.statusCode == 413) {
        throw const ApiException(
          413,
          'too_large',
          'the upload is larger than the size announced in the ticket',
        );
      }
      rethrow;
    }
    if (received.bytes != record.bytes) {
      throw ApiException(
        422,
        'content_mismatch',
        'the received size does not match the presigned ticket',
        fieldErrors: const <String, String>{'content': 'byte_count_mismatch'},
      );
    }
    if (received.sha256 != record.sha256) {
      throw ApiException(
        422,
        'content_mismatch',
        'the received bytes do not match the presigned content address',
        fieldErrors: const <String, String>{'content': 'sha256_mismatch'},
      );
    }
    if (!_matchesMagic(received.prefix, record.mimeType)) {
      throw ApiException(
        422,
        'content_mismatch',
        'the received bytes are not a valid ${record.mimeType}',
        fieldErrors: const <String, String>{'content': 'bad_signature'},
      );
    }

    record
      ..receivedBytes = received.bytes
      ..receivedSha256 = received.sha256
      ..uploaded = true;
    ctx.audit(
      action: 'upload.put',
      objectType: 'upload',
      objectId: uploadId,
      details: <String, Object?>{
        'mimeType': record.mimeType,
        'bytes': received.bytes,
      },
    );
    return ctx.json(<String, Object?>{
      'received': true,
      'bytes': received.bytes,
      'sha256': received.sha256,
    });
  });

  router.post('/v1/uploads/<uploadId>/complete', (
    Request request,
    String uploadId,
  ) async {
    final ctx = contextOf(request);
    ctx.requireSession();
    final record = _ownedUpload(ctx, uploadId);

    if (server.consumeFault('upload_interrupt')) {
      ctx.audit(
        action: 'upload.complete',
        objectType: 'upload',
        objectId: uploadId,
        result: 'failed',
        details: const <String, Object?>{'reason': 'upload_interrupted'},
      );
      throw ApiException(
        503,
        'upload_interrupted',
        'the upload was interrupted; retry with the same ticket',
        headers: const <String, String>{'retry-after': '1'},
      );
    }

    if (record.completed) return ctx.json(record.toDto().toJson());

    if (record.isExpiredAt(server.clock.now())) {
      throw ApiException(
        410,
        'upload_expired',
        'the upload ticket has expired',
      );
    }
    if (!record.uploaded) {
      ctx.audit(
        action: 'upload.complete',
        objectType: 'upload',
        objectId: uploadId,
        result: 'denied',
        details: const <String, Object?>{'reason': 'no_bytes_received'},
      );
      throw ApiException.conflict(
        'upload_incomplete',
        'no bytes were uploaded for this ticket; PUT the original first',
      );
    }

    final body = await ctx.jsonBody();
    final sha = body['sha256'];
    if (sha is! String || sha.toLowerCase() != record.sha256) {
      throw ApiException.validation(
        'sha256 does not match the presigned content address',
        fieldErrors: const <String, String>{'sha256': 'sha256_mismatch'},
      );
    }

    final digest = int.parse(record.sha256.substring(0, 6), radix: 16);
    final width = 1200 + (digest % 3600);
    record
      ..widthPx = width
      ..heightPx = math.max(1, (width * 3 / 4).round())
      ..completed = true;

    ctx.audit(
      action: 'upload.complete',
      objectType: 'upload',
      objectId: uploadId,
      details: <String, Object?>{
        'mimeType': record.mimeType,
        'bytes': record.receivedBytes ?? record.bytes,
      },
    );
    return ctx.json(record.toDto().toJson());
  });

  router.delete('/v1/uploads/<uploadId>', (Request request, String uploadId) {
    final ctx = contextOf(request);
    ctx.requireSession();
    final record = _ownedUpload(ctx, uploadId);
    server.uploads.remove(record.id);
    ctx.audit(
      action: 'upload.delete',
      objectType: 'upload',
      objectId: uploadId,
    );
    return ctx.noContent();
  });
}

UploadRecord _uploadById(MockServer server, String uploadId) {
  final record = server.uploads[uploadId];
  if (record == null) {
    throw ApiException.notFound('upload $uploadId not found');
  }
  return record;
}

UploadRecord _ownedUpload(MockContext ctx, String uploadId) {
  final record = ctx.server.uploads[uploadId];
  if (record == null) {
    throw ApiException.notFound('unknown upload');
  }
  if (record.ownerId != ctx.session!.customerId) {
    ctx.audit(
      action: 'upload.access',
      objectType: 'upload',
      objectId: uploadId,
      result: 'denied',
      details: const <String, Object?>{'reason': 'foreign_upload'},
    );
    throw ApiException.forbidden('the upload belongs to another customer');
  }
  return record;
}

String _safeFileName(String fileName) {
  final base = fileName.split(RegExp(r'[/\\]')).last.trim();
  final cleaned = base.replaceAll(RegExp(r'[\u0000-\u001f]'), '');
  if (cleaned.isEmpty) return 'upload';
  return cleaned.length <= 255 ? cleaned : cleaned.substring(0, 255);
}

const List<int> jpegMagic = <int>[0xff, 0xd8, 0xff];

const List<int> pngMagic = <int>[
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
];

bool _matchesMagic(List<int> prefix, String mimeType) {
  final magic = switch (mimeType) {
    'image/jpeg' => jpegMagic,
    'image/png' => pngMagic,
    _ => null,
  };
  if (magic == null || prefix.length < magic.length) return false;
  for (var i = 0; i < magic.length; i++) {
    if (prefix[i] != magic[i]) return false;
  }
  return true;
}

extension on UploadRecord {
  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now);
}
