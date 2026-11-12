import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

Map<String, Object?> aiRequest({
  String intent = 'warmer',
  Map<String, Object?>? summary,
  Map<String, Object?>? limits,
  String? previewBase64,
  List<Map<String, Object?>> templates = const <Map<String, Object?>>[
    <String, Object?>{'id': 'single_10x15', 'slotCount': 1},
    <String, Object?>{'id': 'duo_10x15', 'slotCount': 2},
    <String, Object?>{'id': 'quad_10x15', 'slotCount': 4},
  ],
}) {
  final document = DesignDocument.fromJsonOrThrow(printDesignJson());
  return <String, Object?>{
    'intent': intent,
    'locale': 'ru',
    'context': <String, Object?>{
      'summary': summary ?? DocumentSummary.from(document).toJson(),
      'spec': const PrintSpec(
        widthMm: 100,
        heightMm: 150,
        bleedMm: 3,
        safeMm: 3,
      ).toJson(),
      'templates': templates,
      'previewBase64': ?previewBase64,
    },
    'limits': limits ?? <String, Object?>{'maxOps': 8},
  };
}

void main() {
  late MockApi api;
  late String token;

  setUp(() async {
    api = MockApi();
    token = await api.login();
  });

  group('POST /v1/ai/patch', () {
    test('answers a typed patch with provenance metadata', () async {
      final response = await api.call(
        'POST',
        '/v1/ai/patch',
        token: token,
        body: aiRequest(),
      );
      expect(response.status, 200, reason: response.text);

      final dto = AiPatchResponse.fromJson(response.object);
      expect(dto.patch.operations, hasLength(1));
      expect(dto.patch.operations.single, isA<SetAdjustmentOperation>());
      final operation = dto.patch.operations.single as SetAdjustmentOperation;
      expect(operation.field, PhotoAdjustmentField.temperature);
      expect(dto.warnings, isEmpty);
      expect(dto.meta.skillId, 'picpac.rules.design');
      expect(dto.meta.skillVersion, isNotEmpty);
      expect(dto.meta.toolSchemaVersion, isNotEmpty);
      expect(dto.meta.model, isNotEmpty);
    });

    test(
      'binds the patch to the revision of the summary it received',
      () async {
        final document = DesignDocument.fromJsonOrThrow(printDesignJson());
        final summary = DocumentSummary.from(document.copyWith(revision: 23));
        final response = await api.call(
          'POST',
          '/v1/ai/patch',
          token: token,
          body: aiRequest(summary: summary.toJson()),
        );
        expect(response.status, 200, reason: response.text);
        expect(
          AiPatchResponse.fromJson(response.object).patch.baseRevision,
          23,
        );
      },
    );

    test('says so when the intent is not recognised', () async {
      final response = await api.call(
        'POST',
        '/v1/ai/patch',
        token: token,
        body: aiRequest(intent: 'сделай красиво как в инстаграме'),
      );
      expect(response.status, 200, reason: response.text);
      final dto = AiPatchResponse.fromJson(response.object);
      expect(dto.patch.isEmpty, isTrue);
      expect(dto.warnings, contains('intent_not_recognised'));
    });

    test('never echoes the preview and never stores it', () async {
      const preview = 'iVBORw0KGgoAAAANSUhEUg==';
      final response = await api.call(
        'POST',
        '/v1/ai/patch',
        token: token,
        body: aiRequest(previewBase64: preview),
      );
      expect(response.status, 200, reason: response.text);
      expect(response.text.contains(preview), isFalse);
    });

    test('rejects a malformed request body', () async {
      final response = await api.call(
        'POST',
        '/v1/ai/patch',
        token: token,
        body: <String, Object?>{'locale': 'ru'},
      );
      expectError(response, 422, ApiErrorCode.validationFailed);
    });

    test('requires a session', () async {
      final response = await api.call(
        'POST',
        '/v1/ai/patch',
        body: aiRequest(),
      );
      expectError(response, 401, ApiErrorCode.unauthorized);
    });
  });
}
