import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

final List<int> jpegPayload = <int>[
  0xff, 0xd8, 0xff, 0xe0, //
  0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01, //
  ...List<int>.filled(24, 0x00),
  0xff, 0xd9,
];

final List<int> pngPayload = <int>[
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, //
  ...List<int>.filled(24, 0x11),
];

String shaOf(List<int> bytes) => sha256.convert(bytes).toString();

void main() {
  late MockApi api;
  late String token;

  setUp(() async {
    api = MockApi();
    token = await api.login();
  });

  Future<MockResponse> presign({
    String mimeType = 'image/jpeg',
    int? bytes,
    String? sha256,
    String fileName = 'photo.jpg',
  }) => api.call(
    'POST',
    '/v1/uploads/presign',
    token: token,
    body: <String, Object?>{
      'fileName': fileName,
      'mimeType': mimeType,
      'bytes': bytes ?? jpegPayload.length,
      'sha256': sha256 ?? shaOf(jpegPayload),
    },
  );

  Future<MockResponse> put(
    UploadTicket ticket,
    List<int> bytes, {
    String mimeType = 'image/jpeg',
    String? as,
  }) => api.call(
    'PUT',
    Uri.parse(ticket.url).path,
    token: as ?? token,
    body: bytes,
    headers: <String, String>{'content-type': mimeType},
  );

  group('uploads', () {
    test('issues a ticket and confirms dimensions on complete', () async {
      final ticketResponse = await presign();
      expect(ticketResponse.status, 200, reason: ticketResponse.text);
      final ticket = UploadTicket.fromJson(ticketResponse.object);
      expect(ticket.method, 'PUT');
      expect(ticket.maxBytes, 25 * 1024 * 1024);
      expect(ticket.url, contains('/v1/mock/uploads/'));
      expect(ticket.headers['x-content-sha256'], shaOf(jpegPayload));
      expect(ticket.expiresAt.isAfter(api.clock.now()), isTrue);

      final uploaded = await put(ticket, jpegPayload);
      expect(uploaded.status, 200, reason: uploaded.text);
      expect(uploaded.object['bytes'], jpegPayload.length);
      expect(uploaded.object['sha256'], shaOf(jpegPayload));

      final completed = await api.call(
        'POST',
        '/v1/uploads/${ticket.uploadId}/complete',
        token: token,
        body: <String, Object?>{'sha256': shaOf(jpegPayload)},
      );
      expect(completed.status, 200, reason: completed.text);
      final upload = CompletedUpload.fromJson(completed.object);
      expect(upload.sha256, shaOf(jpegPayload));
      expect(upload.mimeType, 'image/jpeg');
      expect(upload.widthPx, greaterThan(0));
      expect(upload.heightPx, greaterThan(0));
      expect(upload.bytes, jpegPayload.length);
      expect(upload.toPhotoAsset('p1').bytes, upload.bytes);

      final replay = await api.call(
        'POST',
        '/v1/uploads/${ticket.uploadId}/complete',
        token: token,
        body: <String, Object?>{'sha256': shaOf(jpegPayload)},
      );
      expect(replay.status, 200);
      expect(replay.object['uploadId'], ticket.uploadId);
    });

    test('complete without a PUT is refused', () async {
      final ticket = UploadTicket.fromJson((await presign()).object);
      final response = await api.call(
        'POST',
        '/v1/uploads/${ticket.uploadId}/complete',
        token: token,
        body: <String, Object?>{'sha256': shaOf(jpegPayload)},
      );
      expectError(response, 409, 'upload_incomplete');
      expect(api.server.uploads[ticket.uploadId]!.completed, isFalse);
    });

    test('text sent as image/jpeg is rejected by the magic bytes', () async {
      final text = utf8.encode('this is not an image at all');
      final ticket = UploadTicket.fromJson(
        (await presign(bytes: text.length, sha256: shaOf(text))).object,
      );
      final response = await put(ticket, text);
      expectError(response, 422, 'content_mismatch');
      expect(fieldErrors(response)['content'], 'bad_signature');

      final complete = await api.call(
        'POST',
        '/v1/uploads/${ticket.uploadId}/complete',
        token: token,
        body: <String, Object?>{'sha256': shaOf(text)},
      );
      expectError(complete, 409, 'upload_incomplete');
    });

    test('a valid PNG is accepted, a JPEG body is not', () async {
      final pngTicket = UploadTicket.fromJson(
        (await presign(
          mimeType: 'image/png',
          bytes: pngPayload.length,
          sha256: shaOf(pngPayload),
          fileName: 'scan.png',
        )).object,
      );
      final accepted = await put(pngTicket, pngPayload, mimeType: 'image/png');
      expect(accepted.status, 200, reason: accepted.text);

      final crossed = UploadTicket.fromJson(
        (await presign(
          mimeType: 'image/png',
          bytes: jpegPayload.length,
          sha256: shaOf(jpegPayload),
          fileName: 'scan.png',
        )).object,
      );
      final rejected = await put(crossed, jpegPayload, mimeType: 'image/png');
      expectError(rejected, 422, 'content_mismatch');
      expect(fieldErrors(rejected)['content'], 'bad_signature');
    });

    test('a body larger than the ticket is 413 too_large', () async {
      final ticket = UploadTicket.fromJson(
        (await presign(bytes: 4, sha256: shaOf(jpegPayload))).object,
      );
      final response = await put(ticket, jpegPayload);
      expectError(response, 413, 'too_large');
      expect(api.server.uploads[ticket.uploadId]!.uploaded, isFalse);
    });

    test('a body with a different content address is 422', () async {
      final ticket = UploadTicket.fromJson((await presign()).object);
      final tampered = List<int>.from(jpegPayload)..[12] = 0x7f;
      final response = await put(ticket, tampered);
      expectError(response, 422, 'content_mismatch');
      expect(fieldErrors(response)['content'], 'sha256_mismatch');
    });

    test('rejects HEIC honestly with unsupported_format', () async {
      final response = await presign(mimeType: 'image/heic');
      expectError(response, 422, 'unsupported_format');
      expect(fieldErrors(response)['mimeType'], 'unsupported_format');
    });

    test('rejects an oversized or empty upload', () async {
      final tooLarge = await presign(bytes: 26 * 1024 * 1024);
      expectError(tooLarge, 422, ApiErrorCode.validationFailed);
      expect(fieldErrors(tooLarge)['bytes'], 'too_large');

      final empty = await presign(bytes: 0);
      expect(fieldErrors(empty)['bytes'], 'too_small');
    });

    test('an armed upload_interrupt fault makes one complete fail', () async {
      final ticket = UploadTicket.fromJson((await presign()).object);
      await put(ticket, jpegPayload);
      final arming = await api.call(
        'POST',
        '/v1/mock/faults',
        token: await api.loginSupport(),
        body: <String, Object?>{'mode': 'upload_interrupt'},
      );
      expect(arming.status, 200);

      final failed = await api.call(
        'POST',
        '/v1/uploads/${ticket.uploadId}/complete',
        token: token,
        body: <String, Object?>{'sha256': shaOf(jpegPayload)},
      );
      expectError(failed, 503, 'upload_interrupted');

      final retried = await api.call(
        'POST',
        '/v1/uploads/${ticket.uploadId}/complete',
        token: token,
        body: <String, Object?>{'sha256': shaOf(jpegPayload)},
      );
      expect(retried.status, 200, reason: retried.text);
    });

    test('rejects an unknown fault mode', () async {
      final response = await api.call(
        'POST',
        '/v1/mock/faults',
        token: await api.loginSupport(),
        body: <String, Object?>{'mode': 'self_destruct'},
      );
      expectError(response, 422, ApiErrorCode.validationFailed);
      expect(fieldErrors(response)['mode'], 'unknown_mode');
    });

    test('keeps uploads private and deletable', () async {
      final guest = await api.anonymous();
      final guestTicket = UploadTicket.fromJson(
        (await api.call(
          'POST',
          '/v1/uploads/presign',
          token: guest,
          body: <String, Object?>{
            'fileName': 'guest.png',
            'mimeType': 'image/png',
            'bytes': pngPayload.length,
            'sha256': shaOf(pngPayload),
          },
        )).object,
      );
      final uploadId = guestTicket.uploadId;

      final foreign = await api.call(
        'POST',
        '/v1/uploads/$uploadId/complete',
        token: token,
        body: <String, Object?>{'sha256': shaOf(pngPayload)},
      );
      expectError(foreign, 403, ApiErrorCode.forbidden);

      final foreignPut = await put(
        guestTicket,
        pngPayload,
        mimeType: 'image/png',
        as: token,
      );
      expectError(foreignPut, 403, ApiErrorCode.forbidden);

      expect(
        (await put(
          guestTicket,
          pngPayload,
          mimeType: 'image/png',
          as: guest,
        )).status,
        200,
      );
      final own = await api.call(
        'POST',
        '/v1/uploads/$uploadId/complete',
        token: guest,
        body: <String, Object?>{'sha256': shaOf(pngPayload)},
      );
      expect(own.status, 200, reason: own.text);
      final deleted = await api.call(
        'DELETE',
        '/v1/uploads/$uploadId',
        token: guest,
      );
      expect(deleted.status, 204);
      final again = await api.call(
        'POST',
        '/v1/uploads/$uploadId/complete',
        token: guest,
        body: <String, Object?>{'sha256': shaOf(pngPayload)},
      );
      expectError(again, 404, ApiErrorCode.notFound);
    });

    test('rejects a sha256 that does not match the ticket', () async {
      final ticket = UploadTicket.fromJson((await presign()).object);
      await put(ticket, jpegPayload);
      final response = await api.call(
        'POST',
        '/v1/uploads/${ticket.uploadId}/complete',
        token: token,
        body: <String, Object?>{'sha256': List<String>.filled(64, 'a').join()},
      );
      expectError(response, 422, ApiErrorCode.validationFailed);
      expect(fieldErrors(response)['sha256'], 'sha256_mismatch');
    });
  });
}
