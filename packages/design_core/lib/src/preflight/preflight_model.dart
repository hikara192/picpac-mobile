import 'package:meta/meta.dart';

import '../core/json_read.dart';
import '../core/result.dart';
import '../document/design_format_exception.dart';

enum PreflightCode {
  emptySlot('empty_slot'),

  lowDpi('low_dpi'),

  unsupportedFormat('unsupported_format'),

  safeZone('safe_zone'),

  textOverflow('text_overflow'),

  faceAtEdge('face_at_edge');

  const PreflightCode(this.wire);

  final String wire;

  static PreflightCode? tryParse(String raw) {
    for (final code in values) {
      if (code.wire == raw) return code;
    }
    return null;
  }
}

enum PreflightSeverity {
  info('info'),

  warning('warning'),

  error('error');

  const PreflightSeverity(this.wire);

  final String wire;

  static PreflightSeverity fromWire(String raw) {
    for (final value in values) {
      if (value.wire == raw) return value;
    }
    return PreflightSeverity.warning;
  }
}

enum PreflightFixAction {
  assignPhoto('assign_photo'),

  replacePhoto('replace_photo'),

  lowerZoom('lower_zoom'),

  convertFormat('convert_format'),

  reposition('reposition'),

  reduceText('reduce_text');

  const PreflightFixAction(this.wire);

  final String wire;

  static PreflightFixAction? tryParse(String raw) {
    for (final value in values) {
      if (value.wire == raw) return value;
    }
    return null;
  }
}

abstract final class PreflightMessageKeys {
  static const String emptySlot = 'preflight.emptySlot';

  static const String lowDpi = 'preflight.lowDpi';

  static const String unsupportedFormat = 'preflight.unsupportedFormat';

  static const String safeZone = 'preflight.safeZone';

  static const String textOverflow = 'preflight.textOverflow';

  static const String faceAtEdge = 'preflight.faceAtEdge';

  static String forCode(PreflightCode code) => switch (code) {
    PreflightCode.emptySlot => emptySlot,
    PreflightCode.lowDpi => lowDpi,
    PreflightCode.unsupportedFormat => unsupportedFormat,
    PreflightCode.safeZone => safeZone,
    PreflightCode.textOverflow => textOverflow,
    PreflightCode.faceAtEdge => faceAtEdge,
  };
}

@immutable
final class PreflightIssue {
  const PreflightIssue({
    required this.code,
    required this.severity,
    required this.targetId,
    required this.messageKey,
    this.args = const <String, Object?>{},
    this.fixAction,
    this.spreadId,
    this.slotId,
    this.photoId,
  });

  final PreflightCode code;

  final PreflightSeverity severity;

  final String targetId;

  final String messageKey;

  final Map<String, Object?> args;

  final PreflightFixAction? fixAction;

  final String? spreadId;

  final String? slotId;

  final String? photoId;

  bool get isBlocking => severity == PreflightSeverity.error;

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code.wire,
    'severity': severity.wire,
    'targetId': targetId,
    'messageKey': messageKey,
    if (args.isNotEmpty) 'args': args,
    if (fixAction != null) 'fixAction': fixAction!.wire,
    if (spreadId != null) 'spreadId': spreadId,
    if (slotId != null) 'slotId': slotId,
    if (photoId != null) 'photoId': photoId,
  };

  factory PreflightIssue.fromJson(Object? json, String path) {
    final map = JsonRead.object(json, path);
    final rawCode = JsonRead.id(map['code'], '$path.code');
    final code = PreflightCode.tryParse(rawCode);
    if (code == null) {
      throw DesignFormatException(
        code: DesignFormatErrorCode.invalidValue,
        message: 'unknown preflight code "$rawCode"',
        path: '$path.code',
      );
    }
    final rawFix = JsonRead.optId(map['fixAction'], '$path.fixAction');
    return PreflightIssue(
      code: code,
      severity: PreflightSeverity.fromWire(
        JsonRead.optId(map['severity'], '$path.severity') ?? 'warning',
      ),
      targetId: JsonRead.id(map['targetId'], '$path.targetId'),
      messageKey: JsonRead.id(map['messageKey'], '$path.messageKey'),
      args: map['args'] == null
          ? const <String, Object?>{}
          : JsonRead.object(map['args'], '$path.args'),
      fixAction: rawFix == null ? null : PreflightFixAction.tryParse(rawFix),
      spreadId: JsonRead.optId(map['spreadId'], '$path.spreadId'),
      slotId: JsonRead.optId(map['slotId'], '$path.slotId'),
      photoId: JsonRead.optId(map['photoId'], '$path.photoId'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PreflightIssue &&
      other.code == code &&
      other.severity == severity &&
      other.targetId == targetId &&
      other.messageKey == messageKey &&
      other.fixAction == fixAction &&
      other.spreadId == spreadId &&
      other.slotId == slotId &&
      other.photoId == photoId;

  @override
  int get hashCode => Object.hash(
    code,
    severity,
    targetId,
    messageKey,
    fixAction,
    spreadId,
    slotId,
    photoId,
  );

  @override
  String toString() =>
      'PreflightIssue(${code.wire} ${severity.wire} on $targetId)';
}

@immutable
final class PreflightReport {
  const PreflightReport(this.issues, {this.acknowledged = false});

  static const PreflightReport clean = PreflightReport(<PreflightIssue>[]);

  final List<PreflightIssue> issues;

  final bool acknowledged;

  bool get hasBlockingIssues =>
      issues.any((issue) => issue.severity == PreflightSeverity.error);

  bool get hasWarnings =>
      issues.any((issue) => issue.severity == PreflightSeverity.warning);

  bool get isClean => issues.isEmpty;

  List<PreflightIssue> get blocking =>
      issues.where((issue) => issue.isBlocking).toList();

  int get blockingCount => blocking.length;

  int get warningCount => issues
      .where((issue) => issue.severity == PreflightSeverity.warning)
      .length;

  int get infoCount =>
      issues.where((issue) => issue.severity == PreflightSeverity.info).length;

  Set<PreflightCode> get codes => <PreflightCode>{
    for (final issue in issues) issue.code,
  };

  Map<String, int> get countsByCode {
    final counts = <String, int>{};
    for (final issue in issues) {
      counts[issue.code.wire] = (counts[issue.code.wire] ?? 0) + 1;
    }
    return counts;
  }

  bool get canOrder => !hasBlockingIssues || acknowledged;

  List<PreflightIssue> issuesFor(String targetId) =>
      issues.where((issue) => issue.targetId == targetId).toList();

  PreflightReport acknowledge() =>
      acknowledged ? this : PreflightReport(issues, acknowledged: true);

  PreflightReport without(String targetId) => PreflightReport(<PreflightIssue>[
    for (final issue in issues)
      if (issue.targetId != targetId) issue,
  ], acknowledged: acknowledged);

  Map<String, Object?> toJson() => <String, Object?>{
    'acknowledged': acknowledged,
    'issues': <Object?>[for (final issue in issues) issue.toJson()],
  };

  static Result<PreflightReport> fromJson(Object? json) {
    try {
      final map = JsonRead.object(json, r'$');
      final list = JsonRead.array(map['issues'], r'$.issues');
      return Ok<PreflightReport>(
        PreflightReport(
          List<PreflightIssue>.unmodifiable(<PreflightIssue>[
            for (var i = 0; i < list.length; i++)
              PreflightIssue.fromJson(list[i], '\$.issues[$i]'),
          ]),
          acknowledged: JsonRead.booleanOr(
            map['acknowledged'],
            r'$.acknowledged',
            fallback: false,
          ),
        ),
      );
    } on DesignFormatException catch (error) {
      return Err<PreflightReport>(error);
    }
  }

  @override
  String toString() =>
      'PreflightReport(${issues.length} issues, blocking: $blockingCount, '
      'acknowledged: $acknowledged)';
}

@immutable
final class PreflightConfig {
  const PreflightConfig({
    this.blockingCodes = defaultBlockingCodes,
    this.allowedMimeTypes = defaultAllowedMimeTypes,
    this.dpiTolerance = 1e-6,
    this.safeOverflowToleranceMm = 0.05,
    this.faceEdgeBand = 0.15,
  });

  static const Set<PreflightCode> defaultBlockingCodes = <PreflightCode>{
    PreflightCode.emptySlot,
    PreflightCode.unsupportedFormat,
  };

  static const Set<String> defaultAllowedMimeTypes = <String>{
    'image/jpeg',
    'image/png',
  };

  final Set<PreflightCode> blockingCodes;

  final Set<String> allowedMimeTypes;

  final double dpiTolerance;

  final double safeOverflowToleranceMm;

  final double faceEdgeBand;

  PreflightSeverity severityOf(PreflightCode code) =>
      blockingCodes.contains(code)
      ? PreflightSeverity.error
      : PreflightSeverity.warning;
}
