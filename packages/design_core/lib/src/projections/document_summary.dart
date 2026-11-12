import 'package:meta/meta.dart';

import '../core/json_read.dart';
import '../core/result.dart';
import '../document/design_document.dart';
import '../document/design_format_exception.dart';
import '../document/geometry.dart';
import '../document/slot.dart';

@immutable
final class SpreadSlotSummary {
  const SpreadSlotSummary({
    required this.id,
    required this.crop,
    required this.zoom,
    required this.anchor,
    this.photoId,
  });

  final String id;

  final String? photoId;

  final Crop crop;

  final double zoom;

  final NormalizedPoint anchor;

  bool get isEmpty => photoId == null;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    if (photoId != null) 'photoId': photoId,
    'crop': crop.toJson(),
    'zoom': zoom,
    'anchor': anchor.toJson(),
  };

  factory SpreadSlotSummary.fromJson(Object? json, String path) {
    final map = JsonRead.object(json, path);
    final cropJson = map['crop'];
    final anchorJson = map['anchor'];
    return SpreadSlotSummary(
      id: JsonRead.id(map['id'], '$path.id'),
      photoId: JsonRead.optId(map['photoId'], '$path.photoId'),
      crop: cropJson == null
          ? Crop.full
          : Crop.fromJson(cropJson, '$path.crop'),
      zoom: JsonRead.optNumber(map['zoom'], '$path.zoom') ?? Slot.minZoom,
      anchor: anchorJson == null
          ? NormalizedPoint.center
          : NormalizedPoint.fromJson(anchorJson, '$path.anchor'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SpreadSlotSummary &&
      other.id == id &&
      other.photoId == photoId &&
      other.crop == crop &&
      other.zoom == zoom &&
      other.anchor == anchor;

  @override
  int get hashCode => Object.hash(id, photoId, crop, zoom, anchor);

  @override
  String toString() => 'SpreadSlotSummary($id → ${photoId ?? 'empty'})';
}

@immutable
final class SpreadSummary {
  const SpreadSummary({
    required this.id,
    required this.templateId,
    required this.slotCount,
    required this.filledSlotCount,
    required this.photoIds,
    required this.textIds,
    required this.hasImageBackground,
    this.slots = const <SpreadSlotSummary>[],
  });

  final String id;

  final String templateId;

  final int slotCount;

  final int filledSlotCount;

  final List<String> photoIds;

  final List<String> textIds;

  final bool hasImageBackground;

  final List<SpreadSlotSummary> slots;

  List<SpreadSlotSummary> get emptySlots => <SpreadSlotSummary>[
    for (final slot in slots)
      if (slot.isEmpty) slot,
  ];

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'templateId': templateId,
    'slotCount': slotCount,
    'filledSlotCount': filledSlotCount,
    'photoIds': photoIds,
    'textIds': textIds,
    'hasImageBackground': hasImageBackground,
    'slots': <Object?>[for (final slot in slots) slot.toJson()],
  };

  factory SpreadSummary.fromJson(Object? json, String path) {
    final map = JsonRead.object(json, path);
    final slotsJson = map['slots'];
    return SpreadSummary(
      id: JsonRead.id(map['id'], '$path.id'),
      templateId: JsonRead.id(map['templateId'], '$path.templateId'),
      slotCount: JsonRead.integer(map['slotCount'], '$path.slotCount'),
      filledSlotCount: JsonRead.integer(
        map['filledSlotCount'],
        '$path.filledSlotCount',
      ),
      photoIds: JsonRead.idList(map['photoIds'], '$path.photoIds'),
      textIds: JsonRead.idList(map['textIds'], '$path.textIds'),
      hasImageBackground: JsonRead.booleanOr(
        map['hasImageBackground'],
        '$path.hasImageBackground',
        fallback: false,
      ),
      slots: slotsJson == null
          ? const <SpreadSlotSummary>[]
          : <SpreadSlotSummary>[
              for (
                var i = 0;
                i < JsonRead.array(slotsJson, '$path.slots').length;
                i++
              )
                SpreadSlotSummary.fromJson(
                  JsonRead.array(slotsJson, '$path.slots')[i],
                  '$path.slots[$i]',
                ),
            ],
    );
  }
}

@immutable
final class PhotoStats {
  const PhotoStats({
    required this.photoCount,
    required this.adjustedCount,
    required this.lookUsage,
    required this.maxMagnitude,
  });

  final int photoCount;

  final int adjustedCount;

  final Map<String, int> lookUsage;

  final double maxMagnitude;

  Map<String, Object?> toJson() => <String, Object?>{
    'photoCount': photoCount,
    'adjustedCount': adjustedCount,
    'lookUsage': lookUsage,
    'maxMagnitude': maxMagnitude,
  };

  factory PhotoStats.fromJson(Object? json, String path) {
    final map = JsonRead.object(json, path);
    final looksJson = map['lookUsage'];
    if (looksJson == null) {
      throw DesignFormatException(
        code: DesignFormatErrorCode.missingField,
        message: 'required field is missing',
        path: '$path.lookUsage',
      );
    }
    final looks = JsonRead.object(looksJson, '$path.lookUsage');
    return PhotoStats(
      photoCount: JsonRead.integer(map['photoCount'], '$path.photoCount'),
      adjustedCount: JsonRead.integer(
        map['adjustedCount'],
        '$path.adjustedCount',
      ),
      lookUsage: <String, int>{
        for (final entry in looks.entries)
          entry.key: JsonRead.integer(
            entry.value,
            '$path.lookUsage.${entry.key}',
          ),
      },
      maxMagnitude: JsonRead.number(map['maxMagnitude'], '$path.maxMagnitude'),
    );
  }
}

@immutable
final class DocumentSummary {
  const DocumentSummary({
    required this.productId,
    required this.formatId,
    required this.revision,
    required this.spreadsCount,
    required this.materialisedSpreads,
    required this.coverSpreadId,
    required this.spreads,
    required this.photoStats,
    required this.textCount,
    this.unassignedPhotoIds = const <String>[],
  });

  factory DocumentSummary.from(DesignDocument document) {
    final spreads = <SpreadSummary>[
      for (final spread in document.spreads)
        SpreadSummary(
          id: spread.id,
          templateId: spread.templateId,
          slotCount: spread.slotCount,
          filledSlotCount: spread.filledSlotCount,
          photoIds: <String>[
            for (final slot in spread.slots)
              if (slot.photoId != null) slot.photoId!,
          ],
          textIds: <String>[
            for (final element in document.text)
              if (element.spreadId == spread.id) element.id,
          ],
          hasImageBackground: !spread.background.isColor,
          slots: <SpreadSlotSummary>[
            for (final slot in spread.slots)
              SpreadSlotSummary(
                id: slot.id,
                photoId: slot.photoId,
                crop: slot.crop,
                zoom: slot.zoom,
                anchor: slot.anchor,
              ),
          ],
        ),
    ];
    var adjusted = 0;
    var maxMagnitude = 0.0;
    final looks = <String, int>{};
    for (final adjustment in document.photoAdjustments.values) {
      if (!adjustment.isNeutral) adjusted++;
      if (adjustment.magnitude > maxMagnitude) {
        maxMagnitude = adjustment.magnitude;
      }
      final look = adjustment.look;
      if (look != null && !look.isNeutral) {
        looks[look.id] = (looks[look.id] ?? 0) + 1;
      }
    }
    return DocumentSummary(
      productId: document.product.id,
      formatId: document.product.formatId,
      revision: document.revision,
      spreadsCount: document.spreadsCount,
      materialisedSpreads: document.spreads.length,
      coverSpreadId: document.coverSpreadId,
      spreads: List<SpreadSummary>.unmodifiable(spreads),
      photoStats: PhotoStats(
        photoCount: document.photoCount,
        adjustedCount: adjusted,
        lookUsage: Map<String, int>.unmodifiable(looks),
        maxMagnitude: maxMagnitude,
      ),
      textCount: document.text.length,
      unassignedPhotoIds: List<String>.unmodifiable(<String>[
        for (final asset in document.unassignedAssets) asset.id,
      ]),
    );
  }

  final String productId;

  final String formatId;

  final int revision;

  final int spreadsCount;

  final int materialisedSpreads;

  final String? coverSpreadId;

  final List<SpreadSummary> spreads;

  final PhotoStats photoStats;

  final int textCount;

  final List<String> unassignedPhotoIds;

  int get emptySlotCount {
    var empty = 0;
    for (final spread in spreads) {
      empty += spread.slotCount - spread.filledSlotCount;
    }
    return empty;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'productId': productId,
    'formatId': formatId,
    'revision': revision,
    'spreadsCount': spreadsCount,
    'materialisedSpreads': materialisedSpreads,
    if (coverSpreadId != null) 'coverSpreadId': coverSpreadId,
    'spreads': <Object?>[for (final spread in spreads) spread.toJson()],
    'photoStats': photoStats.toJson(),
    'textCount': textCount,
    'unassignedPhotoIds': unassignedPhotoIds,
  };

  static Result<DocumentSummary> fromJson(Object? json) {
    try {
      return Ok<DocumentSummary>(DocumentSummary.fromJsonOrThrow(json));
    } on DesignFormatException catch (error) {
      return Err<DocumentSummary>(error);
    }
  }

  factory DocumentSummary.fromJsonOrThrow(Object? json) {
    final map = JsonRead.object(json, r'$');
    final spreadsJson = JsonRead.array(map['spreads'], r'$.spreads');
    final spreads = <SpreadSummary>[
      for (var i = 0; i < spreadsJson.length; i++)
        SpreadSummary.fromJson(spreadsJson[i], '\$.spreads[$i]'),
    ];
    final unassigned = map['unassignedPhotoIds'];
    return DocumentSummary(
      productId: JsonRead.id(map['productId'], r'$.productId'),
      formatId: JsonRead.id(map['formatId'], r'$.formatId'),
      revision: JsonRead.integer(map['revision'], r'$.revision'),
      spreadsCount: JsonRead.integer(map['spreadsCount'], r'$.spreadsCount'),
      materialisedSpreads:
          JsonRead.optInteger(
            map['materialisedSpreads'],
            r'$.materialisedSpreads',
          ) ??
          spreads.length,
      coverSpreadId: JsonRead.optId(map['coverSpreadId'], r'$.coverSpreadId'),
      spreads: List<SpreadSummary>.unmodifiable(spreads),
      photoStats: PhotoStats.fromJson(map['photoStats'], r'$.photoStats'),
      textCount: JsonRead.optInteger(map['textCount'], r'$.textCount') ?? 0,
      unassignedPhotoIds: unassigned == null
          ? const <String>[]
          : JsonRead.idList(unassigned, r'$.unassignedPhotoIds'),
    );
  }

  @override
  String toString() =>
      'DocumentSummary($productId/$formatId, ${spreads.length} spreads, '
      '${photoStats.photoCount} photos)';
}
