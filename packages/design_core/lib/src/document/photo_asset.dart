import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../core/json_read.dart';
import '../document/design_format_exception.dart';

@immutable
final class PhotoAsset {
  PhotoAsset({
    required this.id,
    required String sha256,
    required this.widthPx,
    required this.heightPx,
    required this.mimeType,
    required this.bytes,
  }) : sha256 = _normalizeSha256(sha256, widthPx, heightPx, bytes);

  PhotoAsset._trusted({
    required this.id,
    required this.sha256,
    required this.widthPx,
    required this.heightPx,
    required this.mimeType,
    required this.bytes,
  });

  final String id;

  final String sha256;

  final int widthPx;

  final int heightPx;

  final String mimeType;

  final int bytes;

  double get aspect => widthPx / heightPx;

  double get megapixels => widthPx * heightPx / 1000000;

  PhotoAsset copyWith({
    String? id,
    String? sha256,
    int? widthPx,
    int? heightPx,
    String? mimeType,
    int? bytes,
  }) => PhotoAsset._trusted(
    id: id ?? this.id,
    sha256: sha256 ?? this.sha256,
    widthPx: widthPx ?? this.widthPx,
    heightPx: heightPx ?? this.heightPx,
    mimeType: mimeType ?? this.mimeType,
    bytes: bytes ?? this.bytes,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'sha256': sha256,
    'widthPx': widthPx,
    'heightPx': heightPx,
    'mimeType': mimeType,
    'bytes': bytes,
  };

  factory PhotoAsset.fromJson(Object? json, String path) {
    final map = JsonRead.object(json, path);
    final widthPx = JsonRead.integer(map['widthPx'], '$path.widthPx');
    final heightPx = JsonRead.integer(map['heightPx'], '$path.heightPx');
    final bytes = JsonRead.integer(map['bytes'], '$path.bytes');
    if (widthPx <= 0 || heightPx <= 0) {
      throw DesignFormatException(
        code: DesignFormatErrorCode.outOfRange,
        message: 'photo dimensions must be positive',
        path: path,
      );
    }
    if (bytes < 0) {
      throw DesignFormatException(
        code: DesignFormatErrorCode.outOfRange,
        message: 'photo byte size must be non-negative',
        path: '$path.bytes',
      );
    }
    return PhotoAsset(
      id: JsonRead.id(map['id'], '$path.id'),
      sha256: JsonRead.id(map['sha256'], '$path.sha256'),
      widthPx: widthPx,
      heightPx: heightPx,
      mimeType: JsonRead.id(map['mimeType'], '$path.mimeType'),
      bytes: bytes,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PhotoAsset &&
      other.id == id &&
      other.sha256 == sha256 &&
      other.widthPx == widthPx &&
      other.heightPx == heightPx &&
      other.mimeType == mimeType &&
      other.bytes == bytes;

  @override
  int get hashCode =>
      Object.hash(id, sha256, widthPx, heightPx, mimeType, bytes);

  @override
  String toString() =>
      'PhotoAsset($id, ${widthPx}x$heightPx, $mimeType, ${bytes}B)';

  static String _normalizeSha256(
    String value,
    int widthPx,
    int heightPx,
    int bytes,
  ) {
    final normalized = value.toLowerCase();
    if (!_sha256Pattern.hasMatch(normalized)) {
      throw ArgumentError.value(
        value,
        'sha256',
        'must be 64 hex characters (content address)',
      );
    }
    if (widthPx <= 0 || heightPx <= 0) {
      throw ArgumentError.value(
        '$widthPx x $heightPx',
        'dimensions',
        'must be positive',
      );
    }
    if (bytes < 0) {
      throw ArgumentError.value(bytes, 'bytes', 'must be non-negative');
    }
    return normalized;
  }

  static final RegExp _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');
}

@immutable
final class AssetManifest {
  const AssetManifest(this.assets);

  static const AssetManifest empty = AssetManifest(<PhotoAsset>[]);

  final List<PhotoAsset> assets;

  bool get isEmpty => assets.isEmpty;

  bool get isNotEmpty => assets.isNotEmpty;

  Map<String, PhotoAsset> get byId => <String, PhotoAsset>{
    for (final asset in assets) asset.id: asset,
  };

  int get length => assets.length;

  int get totalBytes => assets.fold<int>(0, (sum, a) => sum + a.bytes);

  List<PhotoAsset> missingFrom(Iterable<String> availableIds) {
    final available = availableIds.toSet();
    return assets.where((a) => !available.contains(a.id)).toList();
  }

  List<PhotoAsset> missingHashes(Iterable<String> availableHashes) {
    final available = availableHashes.map((h) => h.toLowerCase()).toSet();
    return assets.where((a) => !available.contains(a.sha256)).toList();
  }

  PhotoAsset? byPhotoId(String photoId) =>
      assets.firstWhereOrNull((a) => a.id == photoId);

  @override
  bool operator ==(Object other) =>
      other is AssetManifest &&
      const ListEquality<PhotoAsset>().equals(other.assets, assets);

  @override
  int get hashCode => const ListEquality<PhotoAsset>().hash(assets);
}
