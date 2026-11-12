import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../core/failure.dart';
import '../core/json_read.dart';
import '../core/result.dart';
import '../document/adjustment_limits.dart';
import '../document/design_format_exception.dart';
import '../document/geometry.dart';
import '../document/look_library.dart';
import '../document/photo_adjustment.dart';
import '../document/slot.dart';
import '../document/spread.dart';

const int kDesignPatchSchema = 1;

const int kMaxPatchOperations = 8;

enum PatchErrorCode {
  unsupportedSchema('unsupported_schema'),

  revisionMismatch('revision_mismatch'),

  emptyPatch('empty_patch'),

  tooManyOperations('too_many_operations'),

  unknownOperation('unknown_operation'),

  invalidOperation('invalid_operation'),

  unknownLook('unknown_look'),

  unknownTemplate('unknown_template'),

  unsupportedBackground('unsupported_background'),

  spreadNotFound('spread_not_found'),

  slotNotFound('slot_not_found'),

  photoNotFound('photo_not_found'),

  noEffect('no_effect'),

  sessionNotReady('session_not_ready'),

  commandRejected('command_rejected');

  const PatchErrorCode(this.wire);

  final String wire;
}

@immutable
final class PatchRejected implements Failure {
  const PatchRejected({
    required this.reason,
    required this.message,
    this.opIndex,
    this.operation,
    this.details = const <String, Object?>{},
  });

  static const String failureCode = 'patch_rejected';

  final PatchErrorCode reason;

  @override
  final String message;

  final int? opIndex;

  final String? operation;

  final Map<String, Object?> details;

  @override
  String get code => failureCode;

  @override
  Map<String, Object?> get args => <String, Object?>{
    'reason': reason.wire,
    if (opIndex != null) 'opIndex': opIndex,
    if (operation != null) 'operation': operation,
    ...details,
  };

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'message': message,
    ...args,
  };

  @override
  String toString() {
    final at = opIndex == null ? '' : ' at op #$opIndex';
    final op = operation == null ? '' : ' ($operation)';
    return 'PatchRejected(${reason.wire})$at$op: $message';
  }
}

@immutable
final class PatchMeta {
  const PatchMeta({
    this.skillId = '',
    this.skillVersion = '',
    this.toolSchemaVersion = '',
    this.model = '',
    this.promptHash = '',
  });

  static const PatchMeta empty = PatchMeta();

  final String skillId;

  final String skillVersion;

  final String toolSchemaVersion;

  final String model;

  final String promptHash;

  bool get isEmpty =>
      skillId.isEmpty &&
      skillVersion.isEmpty &&
      toolSchemaVersion.isEmpty &&
      model.isEmpty &&
      promptHash.isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
    if (skillId.isNotEmpty) 'skill_id': skillId,
    if (skillVersion.isNotEmpty) 'skill_version': skillVersion,
    if (toolSchemaVersion.isNotEmpty) 'tool_schema_version': toolSchemaVersion,
    if (model.isNotEmpty) 'model': model,
    if (promptHash.isNotEmpty) 'prompt_hash': promptHash,
  };

  factory PatchMeta.fromJson(Object? json) {
    if (json == null) return PatchMeta.empty;
    final map = JsonRead.object(json, r'$.meta');
    String read(String key) =>
        JsonRead.optString(map[key], '\$.meta.$key') ?? '';
    return PatchMeta(
      skillId: read('skill_id'),
      skillVersion: read('skill_version'),
      toolSchemaVersion: read('tool_schema_version'),
      model: read('model'),
      promptHash: read('prompt_hash'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PatchMeta &&
      other.skillId == skillId &&
      other.skillVersion == skillVersion &&
      other.toolSchemaVersion == toolSchemaVersion &&
      other.model == model &&
      other.promptHash == promptHash;

  @override
  int get hashCode =>
      Object.hash(skillId, skillVersion, toolSchemaVersion, model, promptHash);

  @override
  String toString() =>
      'PatchMeta(${skillId.isEmpty ? 'anonymous' : skillId}@$skillVersion, '
      'schema $toolSchemaVersion, model $model)';
}

@immutable
sealed class PatchOperation with _WireValue {
  const PatchOperation();

  String get op;

  @override
  Map<String, Object?> toJson();

  @override
  String toString() => 'PatchOperation($op)';
}

mixin _WireValue {
  Map<String, Object?> toJson();

  @override
  bool operator ==(Object other) =>
      other is PatchOperation &&
      other.runtimeType == runtimeType &&
      const DeepCollectionEquality().equals(other.toJson(), toJson());

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(toJson()));
}

final class SetCropOperation extends PatchOperation with _WireValue {
  const SetCropOperation({
    required this.spreadId,
    required this.slotId,
    required this.crop,
    this.zoom,
    this.anchor,
  });

  final String spreadId;

  final String slotId;

  final Crop crop;

  final double? zoom;

  final NormalizedPoint? anchor;

  @override
  String get op => 'setCrop';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'op': op,
    'spreadId': spreadId,
    'slotId': slotId,
    'crop': crop.toJson(),
    if (zoom != null) 'zoom': zoom,
    if (anchor != null) 'anchor': anchor!.toJson(),
  };
}

final class SetAdjustmentOperation extends PatchOperation with _WireValue {
  const SetAdjustmentOperation({
    required this.field,
    required this.value,
    this.photoIds,
  });

  final PhotoAdjustmentField field;

  final double value;

  final List<String>? photoIds;

  @override
  String get op => 'setAdjustment';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'op': op,
    if (photoIds != null) 'photoIds': photoIds,
    'field': field.wire,
    'value': value,
  };
}

final class ApplyLookOperation extends PatchOperation with _WireValue {
  const ApplyLookOperation({
    required this.lookId,
    required this.strength,
    this.photoIds,
  });

  final String lookId;

  final double strength;

  final List<String>? photoIds;

  @override
  String get op => 'applyLook';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'op': op,
    if (photoIds != null) 'photoIds': photoIds,
    'lookId': lookId,
    'strength': strength,
  };
}

final class AssignPhotoOperation extends PatchOperation with _WireValue {
  const AssignPhotoOperation({
    required this.spreadId,
    required this.slotId,
    required this.photoId,
  });

  final String spreadId;

  final String slotId;

  final String? photoId;

  @override
  String get op => 'assignPhoto';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'op': op,
    'spreadId': spreadId,
    'slotId': slotId,
    'photoId': photoId,
  };
}

final class ReplacePhotoOperation extends PatchOperation with _WireValue {
  const ReplacePhotoOperation({
    required this.spreadId,
    required this.slotId,
    required this.photoId,
  });

  final String spreadId;

  final String slotId;

  final String photoId;

  @override
  String get op => 'replacePhoto';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'op': op,
    'spreadId': spreadId,
    'slotId': slotId,
    'photoId': photoId,
  };
}

final class SetBackgroundOperation extends PatchOperation with _WireValue {
  const SetBackgroundOperation({
    required this.type,
    required this.value,
    this.spreadIds,
  });

  final BackgroundType type;

  final String value;

  final List<String>? spreadIds;

  @override
  String get op => 'setBackground';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'op': op,
    if (spreadIds != null) 'spreadIds': spreadIds,
    'type': type.wire,
    'value': value,
  };
}

final class SetLayoutOperation extends PatchOperation with _WireValue {
  const SetLayoutOperation({required this.templateId, this.spreadIds});

  final String templateId;

  final List<String>? spreadIds;

  @override
  String get op => 'setLayout';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'op': op,
    if (spreadIds != null) 'spreadIds': spreadIds,
    'templateId': templateId,
  };
}

final class SwapSlotsOperation extends PatchOperation with _WireValue {
  const SwapSlotsOperation({
    required this.spreadA,
    required this.slotA,
    required this.spreadB,
    required this.slotB,
  });

  final String spreadA;

  final String slotA;

  final String spreadB;

  final String slotB;

  @override
  String get op => 'swapSlots';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'op': op,
    'spreadA': spreadA,
    'slotA': slotA,
    'spreadB': spreadB,
    'slotB': slotB,
  };
}

@immutable
final class DesignPatch {
  const DesignPatch({
    required this.baseRevision,
    required this.operations,
    this.schema = currentSchema,
    this.meta = PatchMeta.empty,
  });

  static const int currentSchema = kDesignPatchSchema;

  const DesignPatch.empty({required this.baseRevision})
    : operations = const <PatchOperation>[],
      schema = currentSchema,
      meta = PatchMeta.empty;

  final int schema;

  final int baseRevision;

  final List<PatchOperation> operations;

  final PatchMeta meta;

  bool get isEmpty => operations.isEmpty;

  int get operationCount => operations.length;

  Map<String, Object?> toJson() => <String, Object?>{
    'schema': schema,
    'baseRevision': baseRevision,
    'ops': <Object?>[for (final operation in operations) operation.toJson()],
    if (!meta.isEmpty) 'meta': meta.toJson(),
  };

  static Result<DesignPatch> fromJson(Object? json) {
    try {
      return Ok<DesignPatch>(fromJsonOrThrow(json));
    } on PatchRejected catch (error) {
      return Err<DesignPatch>(error);
    }
  }

  static DesignPatch fromJsonOrThrow(Object? json) {
    final map = JsonRead.object(json, r'$');
    final schema =
        JsonRead.optInteger(map['schema'], r'$.schema') ?? currentSchema;
    if (schema != currentSchema) {
      throw PatchRejected(
        reason: PatchErrorCode.unsupportedSchema,
        message:
            'patch schema $schema is not supported by this build '
            '($currentSchema)',
        details: <String, Object?>{
          'schema': schema,
          'supported': currentSchema,
        },
      );
    }
    final baseRevision = JsonRead.integer(
      map['baseRevision'],
      r'$.baseRevision',
    );
    if (baseRevision < 0) {
      throw const PatchRejected(
        reason: PatchErrorCode.invalidOperation,
        message: 'baseRevision must be non-negative',
      );
    }
    final rawOps = map['ops'] ?? map['operations'];
    final opsJson = rawOps == null
        ? const <Object?>[]
        : JsonRead.array(rawOps, r'$.ops');
    final operations = <PatchOperation>[
      for (var index = 0; index < opsJson.length; index++)
        _parseOperation(opsJson[index], index),
    ];
    return DesignPatch(
      schema: schema,
      baseRevision: baseRevision,
      operations: List<PatchOperation>.unmodifiable(operations),
      meta: PatchMeta.fromJson(map['meta']),
    );
  }

  static PatchOperation _parseOperation(Object? json, int index) {
    final path = '\$.ops[$index]';
    String? name;
    try {
      final map = JsonRead.object(json, path);
      name = JsonRead.id(map['op'], '$path.op');
      return switch (name) {
        'setCrop' => _parseSetCrop(map, path),
        'setAdjustment' => _parseSetAdjustment(map, path),
        'applyLook' => _parseApplyLook(map, path),
        'assignPhoto' => _parseAssignPhoto(map, path),
        'replacePhoto' => _parseReplacePhoto(map, path),
        'setBackground' => _parseSetBackground(map, path),
        'setLayout' => _parseSetLayout(map, path),
        'swapSlots' => _parseSwapSlots(map, path),
        _ => throw PatchRejected(
          reason: PatchErrorCode.unknownOperation,
          message: 'operation "$name" is not allowed',
          opIndex: index,
          operation: name,
          details: <String, Object?>{'allowed': _allowedOperations},
        ),
      };
    } on PatchRejected catch (error) {
      throw PatchRejected(
        reason: error.reason,
        message: error.message,
        opIndex: index,
        operation: error.operation ?? name,
        details: error.details,
      );
    } on DesignFormatException catch (error) {
      throw PatchRejected(
        reason: PatchErrorCode.invalidOperation,
        message: error.message,
        opIndex: index,
        operation: name,
        details: <String, Object?>{'path': error.path ?? path},
      );
    }
  }

  static const List<String> _allowedOperations = <String>[
    'setCrop',
    'setAdjustment',
    'applyLook',
    'assignPhoto',
    'setBackground',
    'setLayout',
    'swapSlots',
    'replacePhoto',
  ];

  static List<String> get allowedOperations => _allowedOperations;

  static SetCropOperation _parseSetCrop(Map<String, Object?> map, String path) {
    final zoom = JsonRead.optNumber(map['zoom'], '$path.zoom');
    final anchorJson = map['anchor'];
    return SetCropOperation(
      spreadId: JsonRead.id(map['spreadId'], '$path.spreadId'),
      slotId: JsonRead.id(map['slotId'], '$path.slotId'),
      crop: Crop.fromJson(map['crop'], '$path.crop').clamped(),
      zoom: zoom?.clamp(Slot.minZoom, Slot.maxZoom).toDouble(),
      anchor: anchorJson == null
          ? null
          : NormalizedPoint.fromJson(anchorJson, '$path.anchor').clamped(),
    );
  }

  static SetAdjustmentOperation _parseSetAdjustment(
    Map<String, Object?> map,
    String path,
  ) {
    final rawField = JsonRead.string(map['field'], '$path.field');
    final field = PhotoAdjustmentField.tryParse(rawField);
    if (field == null) {
      throw PatchRejected(
        reason: PatchErrorCode.invalidOperation,
        message: 'unknown adjustment field "$rawField"',
        details: <String, Object?>{
          'field': rawField,
          'allowed': <String>[
            for (final value in PhotoAdjustmentField.values) value.wire,
          ],
        },
      );
    }
    final rawValue = JsonRead.number(map['value'], '$path.value');
    return SetAdjustmentOperation(
      field: field,
      value: AdjustmentLimits.of(field).snap(rawValue),
      photoIds: _optionalIds(map['photoIds'], '$path.photoIds'),
    );
  }

  static ApplyLookOperation _parseApplyLook(
    Map<String, Object?> map,
    String path,
  ) {
    final lookId = JsonRead.id(map['lookId'], '$path.lookId');
    if (!LookLibrary.containsId(lookId)) {
      throw PatchRejected(
        reason: PatchErrorCode.unknownLook,
        message: 'unknown look "$lookId" (library v${LookLibrary.version})',
        details: <String, Object?>{
          'lookId': lookId,
          'allowed': LookLibrary.ids,
        },
      );
    }
    final strength = JsonRead.optNumber(map['strength'], '$path.strength') ?? 1;
    return ApplyLookOperation(
      lookId: lookId,
      strength: AdjustmentLimits.clampStrength(strength),
      photoIds: _optionalIds(map['photoIds'], '$path.photoIds'),
    );
  }

  static AssignPhotoOperation _parseAssignPhoto(
    Map<String, Object?> map,
    String path,
  ) => AssignPhotoOperation(
    spreadId: JsonRead.id(map['spreadId'], '$path.spreadId'),
    slotId: JsonRead.id(map['slotId'], '$path.slotId'),
    photoId: JsonRead.optId(map['photoId'], '$path.photoId'),
  );

  static ReplacePhotoOperation _parseReplacePhoto(
    Map<String, Object?> map,
    String path,
  ) => ReplacePhotoOperation(
    spreadId: JsonRead.id(map['spreadId'], '$path.spreadId'),
    slotId: JsonRead.id(map['slotId'], '$path.slotId'),
    photoId: JsonRead.id(map['photoId'], '$path.photoId'),
  );

  static SetBackgroundOperation _parseSetBackground(
    Map<String, Object?> map,
    String path,
  ) {
    final rawType = JsonRead.string(map['type'], '$path.type');
    final type = BackgroundType.fromWire(rawType);
    final value = JsonRead.id(map['value'], '$path.value');
    if (type != BackgroundType.color && type != BackgroundType.gradient) {
      throw PatchRejected(
        reason: PatchErrorCode.unsupportedBackground,
        message:
            'a patch may set a colour or a gradient background, not '
            '"$rawType"',
        details: <String, Object?>{
          'type': rawType,
          'allowed': <String>[
            BackgroundType.color.wire,
            BackgroundType.gradient.wire,
          ],
        },
      );
    }
    if (type == BackgroundType.color) {
      final normalised = _normaliseHex(value);
      if (normalised == null) {
        throw PatchRejected(
          reason: PatchErrorCode.invalidOperation,
          message: 'colour background expects #RRGGBB, got "$value"',
          details: <String, Object?>{'value': value},
        );
      }
      return SetBackgroundOperation(
        type: type,
        value: normalised,
        spreadIds: _optionalIds(map['spreadIds'], '$path.spreadIds'),
      );
    }
    return SetBackgroundOperation(
      type: type,
      value: value,
      spreadIds: _optionalIds(map['spreadIds'], '$path.spreadIds'),
    );
  }

  static SetLayoutOperation _parseSetLayout(
    Map<String, Object?> map,
    String path,
  ) => SetLayoutOperation(
    templateId: JsonRead.id(map['templateId'], '$path.templateId'),
    spreadIds: _optionalIds(map['spreadIds'], '$path.spreadIds'),
  );

  static SwapSlotsOperation _parseSwapSlots(
    Map<String, Object?> map,
    String path,
  ) => SwapSlotsOperation(
    spreadA: JsonRead.id(map['spreadA'], '$path.spreadA'),
    slotA: JsonRead.id(map['slotA'], '$path.slotA'),
    spreadB: JsonRead.id(map['spreadB'], '$path.spreadB'),
    slotB: JsonRead.id(map['slotB'], '$path.slotB'),
  );

  static List<String>? _optionalIds(Object? value, String path) {
    if (value == null) return null;
    final ids = JsonRead.idList(value, path);
    if (ids.isEmpty) {
      throw const DesignFormatException(
        code: DesignFormatErrorCode.invalidValue,
        message: 'an explicit target list must not be empty',
      );
    }
    return List<String>.unmodifiable(ids.toSet());
  }

  static String? _normaliseHex(String value) {
    final raw = value.startsWith('#') ? value.substring(1) : value;
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(raw)) return null;
    return '#${raw.toUpperCase()}';
  }

  @override
  bool operator ==(Object other) =>
      other is DesignPatch &&
      other.schema == schema &&
      other.baseRevision == baseRevision &&
      other.meta == meta &&
      other.operations.length == operations.length &&
      <int>[for (var i = 0; i < operations.length; i++) i]
          .every((i) => other.operations[i] == operations[i]);

  @override
  int get hashCode =>
      Object.hash(schema, baseRevision, meta, Object.hashAll(operations));

  @override
  String toString() =>
      'DesignPatch(schema $schema, base r$baseRevision, '
      '${operations.length} ops)';
}
