import 'package:design_core/design_core.dart';
import 'package:test/test.dart';

DesignDocument fixture({int revision = 7}) {
  return DesignDocument(
    revision: revision,
    product: const DocumentProduct(id: 'photo_print', formatId: '10x15'),
    spreadsCount: 2,
    spreads: <Spread>[
      const Spread(
        id: 's1',
        templateId: BuiltInTemplates.single10x15Id,
        background: SpreadBackground(
          type: BackgroundType.color,
          value: '#FFFFFF',
        ),
        slots: <Slot>[Slot(id: 'main', photoId: 'p1')],
      ),
      const Spread(
        id: 's2',
        templateId: BuiltInTemplates.duo10x15Id,
        background: SpreadBackground(
          type: BackgroundType.color,
          value: '#FFFFFF',
        ),
        slots: <Slot>[
          Slot(id: 'top', photoId: 'p2'),
          Slot(id: 'bottom'),
        ],
      ),
    ],
    assets: <PhotoAsset>[
      PhotoAsset(
        id: 'p1',
        sha256: List<String>.filled(64, 'a').join(),
        widthPx: 3000,
        heightPx: 2000,
        mimeType: 'image/jpeg',
        bytes: 1000,
      ),
      PhotoAsset(
        id: 'p2',
        sha256: List<String>.filled(64, 'b').join(),
        widthPx: 3000,
        heightPx: 2000,
        mimeType: 'image/jpeg',
        bytes: 1000,
      ),
      PhotoAsset(
        id: 'p3',
        sha256: List<String>.filled(64, 'c').join(),
        widthPx: 3000,
        heightPx: 2000,
        mimeType: 'image/jpeg',
        bytes: 1000,
      ),
    ],
  );
}

DesignPatch patchOf(List<Map<String, Object?>> ops, {int baseRevision = 7}) =>
    DesignPatch.fromJsonOrThrow(<String, Object?>{
      'schema': 1,
      'baseRevision': baseRevision,
      'ops': ops,
    });

void main() {
  group('DesignPatch parsing', () {
    test('clamps values instead of writing them out of range', () {
      final patch = patchOf(<Map<String, Object?>>[
        <String, Object?>{
          'op': 'setAdjustment',
          'field': 'temperature',
          'value': 999,
        },
        <String, Object?>{
          'op': 'setCrop',
          'spreadId': 's1',
          'slotId': 'main',
          'crop': <String, Object?>{'x': 3, 'y': 3, 'w': 9, 'h': 9},
          'zoom': 99,
          'anchor': <String, Object?>{'x': 9, 'y': -4},
        },
      ]);

      final adjustment = patch.operations[0] as SetAdjustmentOperation;
      expect(adjustment.value, AdjustmentLimits.temperature.max);
      final crop = patch.operations[1] as SetCropOperation;
      expect(crop.crop.isValid, isTrue);
      expect(crop.zoom, Slot.maxZoom);
      expect(crop.anchor!.isInsideUnitSquare, isTrue);
    });

    test('rejects an unknown operation with its index', () {
      final result = DesignPatch.fromJson(<String, Object?>{
        'schema': 1,
        'baseRevision': 1,
        'ops': <Object?>[
          <String, Object?>{
            'op': 'setAdjustment',
            'field': 'exposure',
            'value': 0.2,
          },
          <String, Object?>{'op': 'deleteEverything'},
        ],
      });
      final error = result.failureOrNull! as PatchRejected;
      expect(error.reason, PatchErrorCode.unknownOperation);
      expect(error.opIndex, 1);
      expect(error.operation, 'deleteEverything');
    });

    test('rejects a wrong type and a field outside the domain', () {
      final wrongType = DesignPatch.fromJson(<String, Object?>{
        'schema': 1,
        'baseRevision': 1,
        'ops': <Object?>[
          <String, Object?>{
            'op': 'setAdjustment',
            'field': 'contrast',
            'value': 'much',
          },
        ],
      });
      expect(wrongType.isErr, isTrue);
      expect(
        (wrongType.failureOrNull! as PatchRejected).reason,
        PatchErrorCode.invalidOperation,
      );

      final unknownField = DesignPatch.fromJson(<String, Object?>{
        'schema': 1,
        'baseRevision': 1,
        'ops': <Object?>[
          <String, Object?>{
            'op': 'setAdjustment',
            'field': 'gamma',
            'value': 1,
          },
        ],
      });
      expect(
        (unknownField.failureOrNull! as PatchRejected).reason,
        PatchErrorCode.invalidOperation,
      );
    });

    test('rejects a look outside the library and an image background', () {
      final look = DesignPatch.fromJson(<String, Object?>{
        'schema': 1,
        'baseRevision': 7,
        'ops': <Object?>[
          <String, Object?>{
            'op': 'applyLook',
            'lookId': 'instagram-2024',
            'strength': 1,
          },
        ],
      });
      expect(
        (look.failureOrNull! as PatchRejected).reason,
        PatchErrorCode.unknownLook,
      );

      final background = DesignPatch.fromJson(<String, Object?>{
        'schema': 1,
        'baseRevision': 7,
        'ops': <Object?>[
          <String, Object?>{
            'op': 'setBackground',
            'type': 'image',
            'value': 'p1',
          },
        ],
      });
      expect(
        (background.failureOrNull! as PatchRejected).reason,
        PatchErrorCode.unsupportedBackground,
      );
    });

    test('round-trips through JSON', () {
      final patch = patchOf(<Map<String, Object?>>[
        <String, Object?>{'op': 'applyLook', 'lookId': 'warm', 'strength': 0.6},
        <String, Object?>{
          'op': 'assignPhoto',
          'spreadId': 's2',
          'slotId': 'bottom',
          'photoId': 'p3',
        },
      ]);
      final again = DesignPatch.fromJsonOrThrow(patch.toJson());
      expect(again, patch);
      expect(again.meta.isEmpty, isTrue);
    });
  });

  group('PatchApplier validation', () {
    test('rejects a stale baseRevision and changes nothing', () {
      final document = fixture();
      final patch = patchOf(<Map<String, Object?>>[
        <String, Object?>{'op': 'applyLook', 'lookId': 'mono', 'strength': 1},
      ], baseRevision: 6);

      final result = PatchApplier.resolve(document, patch);
      final error = result.failureOrNull! as PatchRejected;
      expect(error.reason, PatchErrorCode.revisionMismatch);
      expect(error.args['expected'], 6);
      expect(error.args['actual'], 7);
      expect(document.revision, 7);
    });

    test('rejects the whole patch when one operation references a ghost', () {
      final document = fixture();
      final patch = patchOf(<Map<String, Object?>>[
        <String, Object?>{'op': 'applyLook', 'lookId': 'warm', 'strength': 1},
        <String, Object?>{
          'op': 'assignPhoto',
          'spreadId': 's2',
          'slotId': 'bottom',
          'photoId': 'ghost',
        },
      ]);

      final result = PatchApplier.resolve(document, patch);
      final error = result.failureOrNull! as PatchRejected;
      expect(error.reason, PatchErrorCode.photoNotFound);
      expect(error.opIndex, 1);
      expect(document.photoAdjustments, isEmpty);
    });

    test('rejects more operations than the limit', () {
      final document = fixture();
      final patch = patchOf(<Map<String, Object?>>[
        for (var i = 0; i < 9; i++)
          <String, Object?>{
            'op': 'setAdjustment',
            'field': 'exposure',
            'value': 0.05 * i,
          },
      ]);
      final result = PatchApplier.resolve(document, patch);
      expect(
        (result.failureOrNull! as PatchRejected).reason,
        PatchErrorCode.tooManyOperations,
      );
    });

    test('resolves setLayout against the offered templates only', () {
      final document = fixture();
      final unknown = patchOf(<Map<String, Object?>>[
        <String, Object?>{
          'op': 'setLayout',
          'spreadId': 's1',
          'templateId': 'secret_five_up',
        },
      ]);
      expect(
        (PatchApplier.resolve(document, unknown).failureOrNull!
                as PatchRejected)
            .reason,
        PatchErrorCode.unknownTemplate,
      );

      final known = patchOf(<Map<String, Object?>>[
        <String, Object?>{
          'op': 'setLayout',
          'spreadId': 's2',
          'templateId': BuiltInTemplates.quad10x15Id,
        },
      ]);
      final resolved = PatchApplier.resolve(document, known);
      expect(resolved.isOk, isTrue);
      final applied = resolved.requireValue.command.apply(document);
      expect(
        applied.spreadById('s2')!.templateId,
        BuiltInTemplates.quad10x15Id,
      );
    });
  });

  group('PatchApplier result', () {
    test('is one composite command and one undo step', () {
      final document = fixture();
      final patch = patchOf(<Map<String, Object?>>[
        <String, Object?>{'op': 'applyLook', 'lookId': 'mono', 'strength': 1},
        <String, Object?>{
          'op': 'setAdjustment',
          'field': 'exposure',
          'value': 0.15,
        },
        <String, Object?>{
          'op': 'assignPhoto',
          'spreadId': 's2',
          'slotId': 'bottom',
          'photoId': 'p3',
        },
      ]);

      final resolution = PatchApplier.resolve(document, patch).requireValue;
      final command = PatchApplier.apply(document, patch).requireValue;
      expect(command.commands.length, greaterThan(3));

      final stack = UndoStack(document: document);
      expect(stack.execute(command).isOk, isTrue);
      expect(stack.undoDepth, 1);
      expect(stack.document.revision, document.revision + 1);
      expect(stack.document.adjustmentFor('p1').look?.id, 'mono');
      expect(stack.document.adjustmentFor('p3').look?.id, 'mono');
      expect(stack.document.slotById('s2', 'bottom')!.photoId, 'p3');
      expect(resolution.plan.entries.length, 3);

      expect(stack.undo(), isTrue);
      expect(stack.document, document);
    });

    test('explains an emptied slot in the change plan', () {
      final document = fixture();
      final patch = patchOf(<Map<String, Object?>>[
        <String, Object?>{
          'op': 'assignPhoto',
          'spreadId': 's1',
          'slotId': 'main',
          'photoId': null,
        },
      ]);
      final resolution = PatchApplier.resolve(document, patch).requireValue;
      expect(resolution.plan.removesPhotos, isTrue);
      expect(resolution.plan.entries.single.messageKey, 'aiChangeClearSlot');
      final applied = resolution.previewOf(document);
      expect(applied.slotById('s1', 'main')!.photoId, isNull);
      expect(document.slotById('s1', 'main')!.photoId, 'p1');
    });

    test('dry run warns about a crop that would be unprintable', () {
      final document = fixture();
      final patch = patchOf(<Map<String, Object?>>[
        <String, Object?>{
          'op': 'setCrop',
          'spreadId': 's1',
          'slotId': 'main',
          'crop': <String, Object?>{'x': 0, 'y': 0, 'w': 1, 'h': 1},
          'zoom': 8,
        },
      ]);
      final resolution = PatchApplier.resolve(
        document,
        patch,
        spec: const PrintSpec(widthMm: 100, heightMm: 150, safeMm: 3),
      ).requireValue;
      expect(resolution.warnings, isNotEmpty);
      expect(
        resolution.warnings.map((issue) => issue.code),
        contains(PreflightCode.lowDpi),
      );
      expect(PatchApplier.apply(document, patch).isOk, isTrue);
    });
  });
}
