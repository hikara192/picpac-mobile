import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  test('presigned PUT works without Authorization, complete still needs it', () async {
    final api = MockApi();
    final token = await api.login();
    final bytes = <int>[0xFF, 0xD8, 0xFF, 0xE0, ...List<int>.filled(60, 0)];
    final sha = sha256.convert(bytes).toString();

    final presign = await api.call(
      'POST',
      '/v1/uploads/presign',
      token: token,
      body: <String, Object?>{
        'fileName': 'a.jpg',
        'mimeType': 'image/jpeg',
        'bytes': bytes.length,
        'sha256': sha,
      },
    );
    expect(presign.status, 200, reason: presign.text);
    final ticket = presign.object;
    final uploadId = ticket['uploadId']! as String;
    expect(uploadId, startsWith('upl_'));
    expect(uploadId.length, greaterThan(30), reason: 'id must be unguessable');

    final put = await api.call(
      'PUT',
      '/v1/mock/uploads/$uploadId',
      headers: <String, String>{
        'content-type': 'image/jpeg',
        'x-content-sha256': sha,
      },
      body: bytes,
    );
    expect(put.status, 200, reason: put.text);

    final complete = await api.call(
      'POST',
      '/v1/uploads/$uploadId/complete',
      token: token,
      body: <String, Object?>{'sha256': sha},
    );
    expect(complete.status, 200, reason: complete.text);
  });
}
