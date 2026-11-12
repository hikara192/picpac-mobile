import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  late MockApi api;
  late String token;

  setUp(() async {
    api = MockApi();
    token = await api.login();
  });

  group('design drafts', () {
    test('create, read and delete a document', () async {
      final created = await api.call(
        'POST',
        '/v1/designs',
        token: token,
        body: printDesignJson(),
      );
      expect(created.status, 201, reason: created.text);
      final dto = DesignDto.fromJson(created.object);
      expect(dto.revision, 1);
      expect(dto.document.product.id, 'photo_print');
      expect(dto.document.assets.single.widthPx, 3000);
      expect(created.header('etag'), '"1"');

      final fetched = await api.call(
        'GET',
        '/v1/designs/${dto.id}',
        token: token,
      );
      expect(fetched.status, 200);
      expect(DesignDto.fromJson(fetched.object).document, dto.document);

      final deleted = await api.call(
        'DELETE',
        '/v1/designs/${dto.id}',
        token: token,
      );
      expect(deleted.status, 204);
      final gone = await api.call('GET', '/v1/designs/${dto.id}', token: token);
      expectError(gone, 404, ApiErrorCode.notFound);
    });

    test('rejects a malformed document with field errors', () async {
      final response = await api.call(
        'POST',
        '/v1/designs',
        token: token,
        body: <String, Object?>{'schema': 99, 'product': <String, Object?>{}},
      );
      expectError(response, 422, ApiErrorCode.validationFailed);
      expect(fieldErrors(response)['document'], 'schema_too_new');
    });

    test(
      'requires If-Match and returns the current revision on conflict',
      () async {
        final design = await api.createPrintDesign(token);
        final id = design['id']! as String;

        final missing = await api.call(
          'PUT',
          '/v1/designs/$id',
          token: token,
          body: printDesignJson(),
        );
        expectError(missing, 428, 'precondition_required');
        expect(missing.object['currentRevision'], 1);

        final stale = await api.call(
          'PUT',
          '/v1/designs/$id',
          token: token,
          headers: <String, String>{'if-match': '7'},
          body: printDesignJson(),
        );
        expectError(stale, 409, ApiErrorCode.conflictRevision);
        expect(stale.object['currentRevision'], 1);

        final accepted = await api.call(
          'PUT',
          '/v1/designs/$id',
          token: token,
          headers: <String, String>{'if-match': '"1"'},
          body: printDesignJson(),
        );
        expect(accepted.status, 200, reason: accepted.text);
        final updated = DesignDto.fromJson(accepted.object);
        expect(updated.revision, 2);
        expect(accepted.header('etag'), '"2"');
      },
    );

    test('keeps a design private to its owner', () async {
      final guest = await api.anonymous();
      final created = await api.call(
        'POST',
        '/v1/designs',
        token: guest,
        body: printDesignJson(),
      );
      expect(created.status, 201, reason: created.text);
      final id = created.object['id']! as String;

      final foreign = await api.call('GET', '/v1/designs/$id', token: token);
      expectError(foreign, 403, ApiErrorCode.forbidden);

      final foreignUpdate = await api.call(
        'PUT',
        '/v1/designs/$id',
        token: token,
        headers: <String, String>{'if-match': '1'},
        body: printDesignJson(),
      );
      expectError(foreignUpdate, 403, ApiErrorCode.forbidden);
    });

    test('deleting a design removes it from the cart', () async {
      final design = await api.createPrintDesign(token);
      final id = design['id']! as String;
      final cart = await api.addToCart(token, id);
      expect((cart['items']! as List), hasLength(1));

      await api.call('DELETE', '/v1/designs/$id', token: token);
      final after = await api.call('GET', '/v1/cart', token: token);
      expect((after.object['items']! as List), isEmpty);
    });
  });

  group('preflight', () {
    test('blocks an empty slot and allows a complete spread', () async {
      final blocked = await api.call(
        'POST',
        '/v1/designs',
        token: token,
        body: emptySlotDesignJson(),
      );
      final blockedId = blocked.object['id']! as String;
      final blockedReport = await api.call(
        'POST',
        '/v1/designs/$blockedId/preflight',
        token: token,
      );
      expect(blockedReport.status, 200, reason: blockedReport.text);
      final dto = PreflightDto.fromJson(blockedReport.object);
      expect(dto.canOrder, isFalse);
      expect(dto.hasBlockingIssues, isTrue);
      expect(
        dto.issues.map((issue) => issue.code),
        contains(PreflightCode.emptySlot),
      );
      expect(dto.issues.single.isBlocking, isTrue);

      final clean = await api.createPrintDesign(token);
      final report = await api.call(
        'POST',
        '/v1/designs/${clean['id']}/preflight',
        token: token,
      );
      final cleanDto = PreflightDto.fromJson(report.object);
      expect(cleanDto.canOrder, isTrue);
      expect(cleanDto.issues, isEmpty);
      expect(cleanDto.revision, 0);
    });

    test('rejects a preflight for an unknown stored revision', () async {
      final design = await api.createPrintDesign(token);
      final id = design['id']! as String;
      final response = await api.call(
        'POST',
        '/v1/designs/$id/preflight?revision=9',
        token: token,
      );
      expectError(response, 409, ApiErrorCode.conflictRevision);
      expect(response.object['currentRevision'], 0);
    });
  });
}
