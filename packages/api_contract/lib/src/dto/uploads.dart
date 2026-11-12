import 'package:design_core/design_core.dart';

import '../json.dart';

final class PresignUploadRequest with ValueJson {
  const PresignUploadRequest({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    required this.sha256,
  });

  final String fileName;

  final String mimeType;

  final int bytes;

  final String sha256;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'fileName': fileName,
    'mimeType': mimeType,
    'bytes': bytes,
    'sha256': sha256,
  };

  factory PresignUploadRequest.fromJson(JsonMap json, [String path = r'$']) =>
      PresignUploadRequest(
        fileName: J.readString(json['fileName'], '$path.fileName'),
        mimeType: J.readId(json['mimeType'], '$path.mimeType'),
        bytes: J.readInt(json['bytes'], '$path.bytes'),
        sha256: J.readId(json['sha256'], '$path.sha256'),
      );
}

final class UploadTicket with ValueJson {
  const UploadTicket({
    required this.uploadId,
    required this.url,
    required this.expiresAt,
    this.method = 'PUT',
    this.headers = const <String, String>{},
    this.maxBytes,
  });

  final String uploadId;

  final String url;

  final String method;

  final Map<String, String> headers;

  final DateTime expiresAt;

  final int? maxBytes;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'uploadId': uploadId,
    'url': url,
    'method': method,
    'headers': headers,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    if (maxBytes != null) 'maxBytes': maxBytes,
  };

  factory UploadTicket.fromJson(JsonMap json, [String path = r'$']) =>
      UploadTicket(
        uploadId: J.readId(json['uploadId'], '$path.uploadId'),
        url: J.readId(json['url'], '$path.url'),
        method: J.readIdOrNull(json['method'], '$path.method') ?? 'PUT',
        headers: json['headers'] == null
            ? const <String, String>{}
            : J.readStringMap(json['headers'], '$path.headers'),
        expiresAt: J.readDate(json['expiresAt'], '$path.expiresAt'),
        maxBytes: J.readIntOrNull(json['maxBytes'], '$path.maxBytes'),
      );
}

final class CompletedUpload with ValueJson {
  const CompletedUpload({
    required this.uploadId,
    required this.sha256,
    required this.widthPx,
    required this.heightPx,
    required this.mimeType,
    required this.bytes,
  });

  final String uploadId;

  final String sha256;

  final int widthPx;

  final int heightPx;

  final String mimeType;

  final int bytes;

  PhotoAsset toPhotoAsset(String photoId) => PhotoAsset(
    id: photoId,
    sha256: sha256,
    widthPx: widthPx,
    heightPx: heightPx,
    mimeType: mimeType,
    bytes: bytes,
  );

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'uploadId': uploadId,
    'sha256': sha256,
    'widthPx': widthPx,
    'heightPx': heightPx,
    'mimeType': mimeType,
    'bytes': bytes,
  };

  factory CompletedUpload.fromJson(JsonMap json, [String path = r'$']) =>
      CompletedUpload(
        uploadId: J.readId(json['uploadId'], '$path.uploadId'),
        sha256: J.readId(json['sha256'], '$path.sha256'),
        widthPx: J.readInt(json['widthPx'], '$path.widthPx'),
        heightPx: J.readInt(json['heightPx'], '$path.heightPx'),
        mimeType: J.readId(json['mimeType'], '$path.mimeType'),
        bytes: J.readInt(json['bytes'], '$path.bytes'),
      );
}
