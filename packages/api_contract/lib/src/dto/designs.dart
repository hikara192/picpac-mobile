import 'package:design_core/design_core.dart';

import '../failure.dart';
import '../json.dart';

final class DesignSnapshot with ValueJson {
  const DesignSnapshot({
    required this.revision,
    required this.createdAt,
    this.sizeBytes,
  });

  final int revision;

  final DateTime createdAt;

  final int? sizeBytes;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'revision': revision,
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (sizeBytes != null) 'sizeBytes': sizeBytes,
  };

  factory DesignSnapshot.fromJson(JsonMap json, [String path = r'$']) =>
      DesignSnapshot(
        revision: J.readInt(json['revision'], '$path.revision'),
        createdAt: J.readDate(json['createdAt'], '$path.createdAt'),
        sizeBytes: J.readIntOrNull(json['sizeBytes'], '$path.sizeBytes'),
      );
}

final class DesignDto with ValueJson {
  const DesignDto({
    required this.id,
    required this.revision,
    required this.document,
    required this.updatedAt,
    this.createdAt,
    this.title,
    this.serverSnapshots,
  });

  final String id;

  final int revision;

  final DesignDocument document;

  final DateTime updatedAt;

  final DateTime? createdAt;

  final String? title;

  final List<DesignSnapshot>? serverSnapshots;

  bool get hasSnapshots =>
      (serverSnapshots ?? const <DesignSnapshot>[]).isNotEmpty;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'revision': revision,
    'document': document.toJson(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
    if (title != null) 'title': title,
    if (serverSnapshots != null)
      'serverSnapshots': <Object?>[
        for (final snapshot in serverSnapshots!) snapshot.toJson(),
      ],
  };

  factory DesignDto.fromJson(JsonMap json, [String path = r'$']) {
    final snapshotsJson = json['serverSnapshots'];
    final parsedDocument = DesignDocument.fromJson(json['document']);
    final document = switch (parsedDocument) {
      Ok<DesignDocument>(:final value) => value,
      Err<DesignDocument>(:final error) => throw ApiFailure(
        code: ApiErrorCode.invalidResponse,
        message: 'invalid design document: ${error.message}',
        args: <String, Object?>{
          'path': '$path.document',
          'documentCode': error.code,
        },
      ),
    };
    return DesignDto(
      id: J.readId(json['id'], '$path.id'),
      revision: J.readInt(json['revision'], '$path.revision'),
      document: document,
      updatedAt: J.readDate(json['updatedAt'], '$path.updatedAt'),
      createdAt: J.readDateOrNull(json['createdAt'], '$path.createdAt'),
      title: J.readIdOrNull(json['title'], '$path.title'),
      serverSnapshots: snapshotsJson == null
          ? null
          : <DesignSnapshot>[
              for (
                var i = 0;
                i < J.readList(snapshotsJson, '$path.serverSnapshots').length;
                i++
              )
                DesignSnapshot.fromJson(
                  J.readObject(
                    J.readList(snapshotsJson, '$path.serverSnapshots')[i],
                    '$path.serverSnapshots[$i]',
                  ),
                  '$path.serverSnapshots[$i]',
                ),
            ],
    );
  }
}

final class PreflightDto with ValueJson {
  const PreflightDto({
    required this.revision,
    required this.canOrder,
    this.issues = const <PreflightIssue>[],
    this.acknowledged = false,
  });

  final int revision;

  final bool canOrder;

  final List<PreflightIssue> issues;

  final bool acknowledged;

  bool get hasBlockingIssues => issues.any((issue) => issue.isBlocking);

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'revision': revision,
    'canOrder': canOrder,
    'acknowledged': acknowledged,
    'issues': <Object?>[for (final issue in issues) issue.toJson()],
  };

  factory PreflightDto.fromJson(JsonMap json, [String path = r'$']) {
    final issuesJson = json['issues'] == null
        ? const <Object?>[]
        : J.readList(json['issues'], '$path.issues');
    return PreflightDto(
      revision: J.readInt(json['revision'], '$path.revision'),
      canOrder: J.readBoolOr(
        json['canOrder'],
        '$path.canOrder',
        fallback: false,
      ),
      acknowledged: J.readBoolOr(
        json['acknowledged'],
        '$path.acknowledged',
        fallback: false,
      ),
      issues: <PreflightIssue>[
        for (var i = 0; i < issuesJson.length; i++)
          PreflightIssue.fromJson(issuesJson[i], '$path.issues[$i]'),
      ],
    );
  }

  factory PreflightDto.fromReport(
    PreflightReport report, {
    required int revision,
    required bool canOrder,
  }) => PreflightDto(
    revision: revision,
    canOrder: canOrder,
    issues: report.issues,
    acknowledged: report.acknowledged,
  );
}
