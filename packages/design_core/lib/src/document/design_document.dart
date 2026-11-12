import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../core/json_read.dart';
import '../core/result.dart';
import 'design_format_exception.dart';
import 'photo_adjustment.dart';
import 'photo_asset.dart';
import 'slot.dart';
import 'spread.dart';
import 'text_element.dart';

@immutable
final class DocumentProduct {
  const DocumentProduct({
    required this.id,
    required this.formatId,
    this.options = const <String, String>{},
  });

  final String id;

  final String formatId;

  final Map<String, String> options;

  DocumentProduct copyWith({
    String? id,
    String? formatId,
    Map<String, String>? options,
  }) => DocumentProduct(
    id: id ?? this.id,
    formatId: formatId ?? this.formatId,
    options: options ?? this.options,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'formatId': formatId,
    'options': <String, Object?>{
      for (final key in options.keys.toList()..sort()) key: options[key],
    },
  };

  factory DocumentProduct.fromJson(Object? json, String path) {
    final map = JsonRead.object(json, path);
    final optionsJson = map['options'];
    return DocumentProduct(
      id: JsonRead.id(map['id'], '$path.id'),
      formatId: JsonRead.id(map['formatId'], '$path.formatId'),
      options: optionsJson == null
          ? const <String, String>{}
          : JsonRead.stringMap(optionsJson, '$path.options'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DocumentProduct &&
      other.id == id &&
      other.formatId == formatId &&
      const MapEquality<String, String>().equals(other.options, options);

  @override
  int get hashCode => Object.hash(
    id,
    formatId,
    const MapEquality<String, String>().hash(options),
  );

  @override
  String toString() => 'DocumentProduct($id/$formatId, options: $options)';
}

@immutable
final class DesignDocument {
  const DesignDocument({
    this.schema = currentSchema,
    this.revision = 0,
    required this.product,
    this.spreads = const <Spread>[],
    this.photoAdjustments = const <String, PhotoAdjustment>{},
    this.text = const <TextElement>[],
    this.spreadsCount = 0,
    this.assets = const <PhotoAsset>[],
    this.coverSpreadId,
  });

  static const int currentSchema = 3;

  factory DesignDocument.start({required DocumentProduct product}) =>
      DesignDocument(product: product);

  final int schema;

  final int revision;

  final DocumentProduct product;

  final List<Spread> spreads;

  final Map<String, PhotoAdjustment> photoAdjustments;

  final List<TextElement> text;

  final int spreadsCount;

  final List<PhotoAsset> assets;

  final String? coverSpreadId;

  Iterable<SlotRef> get photoPlacements sync* {
    for (final spread in spreads) {
      for (final slot in spread.slots) {
        final photoId = slot.photoId;
        if (photoId != null) {
          yield SlotRef(spreadId: spread.id, slotId: slot.id, photoId: photoId);
        }
      }
    }
  }

  List<String> get orderedPhotoIds => <String>[
    for (final ref in photoPlacements) ref.photoId,
  ];

  Set<String> get usedPhotoIds => <String>{
    for (final ref in photoPlacements) ref.photoId,
  };

  List<PhotoAsset> get unassignedAssets =>
      assets.where((asset) => !usedPhotoIds.contains(asset.id)).toList();

  int get photoCount => assets.length;

  int get filledSlotCount {
    var count = 0;
    for (final spread in spreads) {
      count += spread.filledSlotCount;
    }
    return count;
  }

  int get emptySlotCount {
    var count = 0;
    for (final spread in spreads) {
      count += spread.emptySlotCount;
    }
    return count;
  }

  bool get hasEmptySlots => spreads.any((spread) => spread.hasEmptySlots);

  bool get hasPhotos => filledSlotCount > 0;

  AssetManifest get manifest => AssetManifest(assets);

  Spread? spreadById(String spreadId) =>
      spreads.firstWhereOrNull((spread) => spread.id == spreadId);

  PhotoAsset? assetById(String photoId) =>
      assets.firstWhereOrNull((asset) => asset.id == photoId);

  Slot? slotById(String spreadId, String slotId) =>
      spreadById(spreadId)?.slotById(slotId);

  List<SlotRef> slotsForPhoto(String photoId) => <SlotRef>[
    for (final ref in photoPlacements)
      if (ref.photoId == photoId) ref,
  ];

  PhotoAdjustment adjustmentFor(String photoId) =>
      photoAdjustments[photoId] ?? PhotoAdjustment.neutral;

  Crop effectiveCropFor(Slot slot) => slot.effectiveSourceWindow;

  List<TextElement> textForSpread(String spreadId) => <TextElement>[
    for (final element in text)
      if (element.spreadId == spreadId) element,
  ];

  DesignDocument copyWith({
    int? schema,
    int? revision,
    DocumentProduct? product,
    List<Spread>? spreads,
    Map<String, PhotoAdjustment>? photoAdjustments,
    List<TextElement>? text,
    int? spreadsCount,
    List<PhotoAsset>? assets,
    Object? coverSpreadId = _unset,
  }) => DesignDocument(
    schema: schema ?? this.schema,
    revision: revision ?? this.revision,
    product: product ?? this.product,
    spreads: spreads ?? this.spreads,
    photoAdjustments: photoAdjustments ?? this.photoAdjustments,
    text: text ?? this.text,
    spreadsCount: spreadsCount ?? this.spreadsCount,
    assets: assets ?? this.assets,
    coverSpreadId: identical(coverSpreadId, _unset)
        ? this.coverSpreadId
        : coverSpreadId as String?,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schema': schema,
    'revision': revision,
    'product': product.toJson(),
    'spreadsCount': spreadsCount,
    'spreads': <Object?>[for (final spread in spreads) spread.toJson()],
    'photoAdjustments': <String, Object?>{
      for (final key in photoAdjustments.keys.toList()..sort())
        key: photoAdjustments[key]!.toJson(),
    },
    'text': <Object?>[for (final element in text) element.toJson()],
    'assets': <Object?>[for (final asset in assets) asset.toJson()],
    if (coverSpreadId != null) 'coverSpreadId': coverSpreadId,
  };

  static Result<DesignDocument> fromJson(Object? json) {
    try {
      return Ok<DesignDocument>(fromJsonOrThrow(json));
    } on DesignFormatException catch (error) {
      return Err<DesignDocument>(error);
    }
  }

  static DesignDocument fromJsonOrThrow(Object? json) {
    final map = JsonRead.object(json, r'$');
    final schema = JsonRead.integer(map['schema'], r'$.schema');
    if (schema > currentSchema) {
      throw DesignFormatException(
        code: DesignFormatErrorCode.schemaTooNew,
        message:
            'document schema $schema is newer than supported $currentSchema',
        path: r'$.schema',
        args: <String, Object?>{'schema': schema, 'supported': currentSchema},
      );
    }
    if (schema < currentSchema) {
      throw DesignFormatException(
        code: DesignFormatErrorCode.schemaUnsupported,
        message: 'document schema $schema has no migration in this build',
        path: r'$.schema',
        args: <String, Object?>{'schema': schema, 'supported': currentSchema},
      );
    }

    final revision = JsonRead.integer(map['revision'], r'$.revision');
    if (revision < 0) {
      throw const DesignFormatException(
        code: DesignFormatErrorCode.outOfRange,
        message: 'revision must be non-negative',
        path: r'$.revision',
      );
    }

    final product = DocumentProduct.fromJson(map['product'], r'$.product');

    final assetsJson = map['assets'];
    final assets = <PhotoAsset>[];
    if (assetsJson != null) {
      final list = JsonRead.array(assetsJson, r'$.assets');
      final seen = <String>{};
      for (var i = 0; i < list.length; i++) {
        final asset = PhotoAsset.fromJson(list[i], '\$.assets[$i]');
        if (!seen.add(asset.id)) {
          throw DesignFormatException(
            code: DesignFormatErrorCode.duplicateId,
            message: 'duplicate asset id "${asset.id}"',
            path: '\$.assets[$i].id',
          );
        }
        assets.add(asset);
      }
    }
    final assetIds = <String>{for (final asset in assets) asset.id};

    final spreadsJson = JsonRead.array(map['spreads'], r'$.spreads');
    final spreads = <Spread>[];
    final spreadIds = <String>{};
    for (var i = 0; i < spreadsJson.length; i++) {
      final spread = Spread.fromJson(spreadsJson[i], '\$.spreads[$i]');
      if (!spreadIds.add(spread.id)) {
        throw DesignFormatException(
          code: DesignFormatErrorCode.duplicateId,
          message: 'duplicate spread id "${spread.id}"',
          path: '\$.spreads[$i].id',
        );
      }
      for (var s = 0; s < spread.slots.length; s++) {
        final photoId = spread.slots[s].photoId;
        if (photoId != null && !assetIds.contains(photoId)) {
          throw DesignFormatException(
            code: DesignFormatErrorCode.invalidReference,
            message: 'slot references unknown photo "$photoId"',
            path: '\$.spreads[$i].slots[$s].photoId',
            args: <String, Object?>{'photoId': photoId},
          );
        }
      }
      spreads.add(spread);
    }

    final adjustmentsJson = map['photoAdjustments'];
    final adjustments = <String, PhotoAdjustment>{};
    if (adjustmentsJson != null) {
      final object = JsonRead.object(adjustmentsJson, r'$.photoAdjustments');
      for (final entry in object.entries) {
        if (entry.key.trim().isEmpty) {
          throw const DesignFormatException(
            code: DesignFormatErrorCode.invalidValue,
            message: 'photoAdjustments keys must be photo ids',
            path: r'$.photoAdjustments',
          );
        }
        if (!assetIds.contains(entry.key)) {
          throw DesignFormatException(
            code: DesignFormatErrorCode.invalidReference,
            message: 'adjustment references unknown photo "${entry.key}"',
            path: '\$.photoAdjustments.${entry.key}',
          );
        }
        adjustments[entry.key] = PhotoAdjustment.fromJson(
          entry.value,
          '\$.photoAdjustments.${entry.key}',
        );
      }
    }

    final textJson = map['text'];
    final textElements = <TextElement>[];
    if (textJson != null) {
      final list = JsonRead.array(textJson, r'$.text');
      final seen = <String>{};
      for (var i = 0; i < list.length; i++) {
        final element = TextElement.fromJson(list[i], '\$.text[$i]');
        if (!seen.add(element.id)) {
          throw DesignFormatException(
            code: DesignFormatErrorCode.duplicateId,
            message: 'duplicate text id "${element.id}"',
            path: '\$.text[$i].id',
          );
        }
        if (!spreadIds.contains(element.spreadId)) {
          throw DesignFormatException(
            code: DesignFormatErrorCode.invalidReference,
            message: 'text references unknown spread "${element.spreadId}"',
            path: '\$.text[$i].spreadId',
          );
        }
        textElements.add(element);
      }
    }

    final spreadsCount = JsonRead.integer(
      map['spreadsCount'],
      r'$.spreadsCount',
    );
    if (spreadsCount < spreads.length) {
      throw DesignFormatException(
        code: DesignFormatErrorCode.outOfRange,
        message: 'spreadsCount must be >= materialised spreads',
        path: r'$.spreadsCount',
        args: <String, Object?>{
          'spreadsCount': spreadsCount,
          'spreads': spreads.length,
        },
      );
    }

    final coverSpreadId = JsonRead.optId(
      map['coverSpreadId'],
      r'$.coverSpreadId',
    );
    if (coverSpreadId != null && !spreadIds.contains(coverSpreadId)) {
      throw DesignFormatException(
        code: DesignFormatErrorCode.invalidReference,
        message: 'cover references unknown spread "$coverSpreadId"',
        path: r'$.coverSpreadId',
      );
    }

    return DesignDocument(
      schema: schema,
      revision: revision,
      product: product,
      spreads: List<Spread>.unmodifiable(spreads),
      photoAdjustments: Map<String, PhotoAdjustment>.unmodifiable(adjustments),
      text: List<TextElement>.unmodifiable(textElements),
      spreadsCount: spreadsCount,
      assets: List<PhotoAsset>.unmodifiable(assets),
      coverSpreadId: coverSpreadId,
    );
  }

  List<String> invariantViolations() {
    final problems = <String>[];
    if (spreadsCount < spreads.length) {
      problems.add('spreadsCount $spreadsCount < spreads ${spreads.length}');
    }
    final spreadIds = <String>{};
    for (final spread in spreads) {
      if (!spreadIds.add(spread.id)) {
        problems.add('duplicate spread ${spread.id}');
      }
      final slotIds = <String>{};
      for (final slot in spread.slots) {
        if (!slotIds.add(slot.id)) {
          problems.add('duplicate slot ${spread.id}/${slot.id}');
        }
        final photoId = slot.photoId;
        if (photoId != null && assetById(photoId) == null) {
          problems.add('slot ${spread.id}/${slot.id} references $photoId');
        }
      }
    }
    for (final entry in photoAdjustments.entries) {
      if (assetById(entry.key) == null) {
        problems.add('adjustment for missing photo ${entry.key}');
      }
    }
    final cover = coverSpreadId;
    if (cover != null && !spreadIds.contains(cover)) {
      problems.add('cover references missing spread $cover');
    }
    for (final element in text) {
      if (!spreadIds.contains(element.spreadId)) {
        problems.add('text ${element.id} references ${element.spreadId}');
      }
    }
    return problems;
  }

  @override
  bool operator ==(Object other) =>
      other is DesignDocument &&
      other.schema == schema &&
      other.revision == revision &&
      other.product == product &&
      other.spreadsCount == spreadsCount &&
      other.coverSpreadId == coverSpreadId &&
      const DeepCollectionEquality().equals(other.spreads, spreads) &&
      const DeepCollectionEquality().equals(
        other.photoAdjustments,
        photoAdjustments,
      ) &&
      const DeepCollectionEquality().equals(other.text, text) &&
      const DeepCollectionEquality().equals(other.assets, assets);

  @override
  int get hashCode => Object.hash(
    schema,
    revision,
    product,
    spreadsCount,
    coverSpreadId,
    const DeepCollectionEquality().hash(spreads),
    const DeepCollectionEquality().hash(photoAdjustments),
    const DeepCollectionEquality().hash(text),
    const DeepCollectionEquality().hash(assets),
  );

  @override
  String toString() =>
      'DesignDocument(r$revision, ${product.id}/${product.formatId}, '
      '${spreads.length} spreads, ${assets.length} photos)';
}

const Object _unset = Object();
