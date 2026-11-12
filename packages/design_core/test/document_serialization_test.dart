import 'dart:convert';

import 'package:design_core/design_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  group('document serialization', () {
    test('round-trips the ten-photo project through JSON', () {
      final document = tenPhotoProject();
      final decoded = DesignDocument.fromJson(
        jsonDecode(jsonEncode(document.toJson())),
      );
      expect(decoded.isOk, isTrue, reason: '${decoded.failureOrNull}');
      expect(decoded.requireValue, document);
      expect(decoded.requireValue.toJson(), document.toJson());
    });

    test('ignores unknown fields (forward compatibility)', () {
      final json = tenPhotoProject().toJson();
      json['futureTopLevel'] = <String, Object?>{'a': 1};
      final spreads = json['spreads']! as List<Object?>;
      final firstSpread = spreads.first! as Map<String, Object?>;
      firstSpread['futureSpreadField'] = 'x';
      final slots = firstSpread['slots']! as List<Object?>;
      (slots.first! as Map<String, Object?>)['futureSlotField'] = 42;

      final decoded = DesignDocument.fromJson(json);
      expect(decoded.isOk, isTrue);
      expect(decoded.requireValue.revision, 0);
    });

    test('rejects a newer schema with schema_too_new', () {
      final json = tenPhotoProject().toJson();
      json['schema'] = DesignDocument.currentSchema + 1;
      final decoded = DesignDocument.fromJson(json);
      expect(decoded.isErr, isTrue);
      expect(decoded.failureOrNull!.code, DesignFormatErrorCode.schemaTooNew);
      expect(
        (decoded.failureOrNull! as DesignFormatException).path,
        contains('schema'),
      );
    });

    test('rejects an older schema with schema_unsupported', () {
      final json = tenPhotoProject().toJson();
      json['schema'] = DesignDocument.currentSchema - 1;
      final decoded = DesignDocument.fromJson(json);
      expect(
        decoded.failureOrNull!.code,
        DesignFormatErrorCode.schemaUnsupported,
      );
    });

    test('missing required field is a typed failure, not an exception', () {
      final json = tenPhotoProject().toJson()..remove('product');
      final decoded = DesignDocument.fromJson(json);
      expect(decoded.failureOrNull!.code, DesignFormatErrorCode.missingField);
    });

    test('duplicate asset ids are rejected', () {
      final json = tenPhotoProject().toJson();
      final assets = json['assets']! as List<Object?>;
      assets[1] = assets[0];
      final decoded = DesignDocument.fromJson(json);
      expect(decoded.failureOrNull!.code, DesignFormatErrorCode.duplicateId);
    });

    test('slot referencing an unknown photo is rejected', () {
      final json = tenPhotoProject().toJson();
      final spreads = json['spreads']! as List<Object?>;
      final firstSpread = spreads.first! as Map<String, Object?>;
      final slots = firstSpread['slots']! as List<Object?>;
      (slots.first! as Map<String, Object?>)['photoId'] = 'ghost';
      final decoded = DesignDocument.fromJson(json);
      expect(
        decoded.failureOrNull!.code,
        DesignFormatErrorCode.invalidReference,
      );
    });

    test('spreadsCount below materialised spreads is rejected', () {
      final json = tenPhotoProject().toJson();
      json['spreadsCount'] = 1;
      final decoded = DesignDocument.fromJson(json);
      expect(decoded.failureOrNull!.code, DesignFormatErrorCode.outOfRange);
    });

    test('unknown background kind survives a round-trip', () {
      final document = DesignDocument(
        product: printProduct,
        spreads: <Spread>[
          Spread(
            id: 's0',
            templateId: 'single_10x15',
            background: const SpreadBackground(
              type: BackgroundType.other,
              value: 'asset-42',
              rawType: 'video',
            ),
            slots: const <Slot>[Slot(id: 'main')],
          ),
        ],
        spreadsCount: 1,
      );
      final json = document.toJson();
      expect(
        ((json['spreads']! as List<Object?>).first!
            as Map<String, Object?>)['background'],
        <String, Object?>{'type': 'video', 'value': 'asset-42'},
      );
      expect(DesignDocument.fromJson(json).requireValue, document);
    });

    test('absent adjustment means neutral', () {
      final document = tenPhotoProject();
      expect(document.adjustmentFor('p0'), PhotoAdjustment.neutral);
      expect(document.photoAdjustments, isEmpty);
    });

    test('invariantViolations is empty for a consistent document', () {
      expect(tenPhotoProject().invariantViolations(), isEmpty);
    });
  });

  group('print spec', () {
    test('derives target pixels from millimetres at 300 dpi', () {
      expect(print10x15Spec.dpi, 300);
      expect(print10x15Spec.targetPxWidth, 1181);
      expect(print10x15Spec.targetPxHeight, 1772);
    });

    test('spread geometry falls back to page geometry', () {
      expect(print10x15Spec.effectiveSpreadWidthMm, 100);
      final book = print10x15Spec.copyWith(
        spreadWidthMm: 400,
        spreadHeightMm: 203,
      );
      expect(book.effectiveSpreadWidthMm, 400);
      expect(book.safeWidthFraction, 0);
    });

    test('zero-sized print spec is rejected', () {
      expect(
        () => PrintSpec.fromJson(<String, Object?>{
          'widthMm': 0,
          'heightMm': 150,
        }, r'$.print'),
        throwsA(
          isA<DesignFormatException>().having(
            (error) => error.code,
            'code',
            DesignFormatErrorCode.outOfRange,
          ),
        ),
      );
    });

    test('negative bleed is rejected with out_of_range', () {
      expect(
        () => PrintSpec.fromJson(<String, Object?>{
          'widthMm': 100,
          'heightMm': 150,
          'bleedMm': -1,
        }, r'$.print'),
        throwsA(
          isA<DesignFormatException>().having(
            (error) => error.code,
            'code',
            DesignFormatErrorCode.outOfRange,
          ),
        ),
      );
    });
  });

  group('asset manifest', () {
    test('reports total budget and missing files', () {
      final document = tenPhotoProject();
      final manifest = document.manifest;
      expect(manifest.length, 10);
      expect(manifest.totalBytes, 10 * 1024 * 1024);
      expect(manifest.missingFrom(<String>['p0', 'p1']).length, 8);
      expect(manifest.byPhotoId('p3')!.id, 'p3');
    });

    test('rejects a malformed content address', () {
      expect(
        () => PhotoAsset(
          id: 'p0',
          sha256: 'not-a-hash',
          widthPx: 10,
          heightPx: 10,
          mimeType: 'image/jpeg',
          bytes: 1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('photo count projection', () {
    test('counts slots and unused photos', () {
      final document = tenPhotoProject();
      final projection = PhotoCountProjection.from(document);
      expect(projection.spreadCount, 10);
      expect(projection.slotCount, 10);
      expect(projection.filledSlotCount, 10);
      expect(projection.emptySlotCount, 0);
      expect(projection.isComplete, isTrue);
      expect(projection.unusedPhotoCount, 0);
      expect(projection.photoCount, 10);
    });
  });

  group('document summary', () {
    test('contains no hashes, bytes or pixel dimensions', () {
      final document = tenPhotoProject().copyWith(
        photoAdjustments: <String, PhotoAdjustment>{
          'p0': const PhotoAdjustment(
            exposure: 0.5,
            look: LookSetting(id: 'warm', strength: 0.6),
          ),
        },
      );
      final summary = DocumentSummary.from(document);
      final json = jsonEncode(summary.toJson());
      expect(json.contains('sha256'), isFalse);
      expect(json.contains('bytes'), isFalse);
      expect(json.contains('widthPx'), isFalse);
      expect(summary.photoStats.photoCount, 10);
      expect(summary.photoStats.adjustedCount, 1);
      expect(summary.photoStats.lookUsage['warm'], 1);
      expect(summary.spreads.first.filledSlotCount, 1);
    });
  });
}
