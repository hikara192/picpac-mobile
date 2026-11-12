import 'package:design_core/design_core.dart';

final class ApiFailure implements Failure {
  const ApiFailure({
    required this.code,
    required this.message,
    this.statusCode,
    this.requestId,
    this.fieldErrors = const <String, String>{},
    this.args = const <String, Object?>{},
  });

  factory ApiFailure.invalidResponse({
    String path = r'$',
    String? expected,
    String? message,
  }) => ApiFailure(
    code: ApiErrorCode.invalidResponse,
    message: message ?? 'invalid response payload',
    args: <String, Object?>{'path': path, 'expected': ?expected},
  );

  factory ApiFailure.networkUnavailable({String? message}) => ApiFailure(
    code: ApiErrorCode.networkUnavailable,
    message: message ?? 'network is unavailable',
  );

  factory ApiFailure.timeout({String? message}) => ApiFailure(
    code: ApiErrorCode.timeout,
    message: message ?? 'request timed out',
  );

  @override
  final String code;

  @override
  final String message;

  final int? statusCode;

  final String? requestId;

  final Map<String, String> fieldErrors;

  @override
  final Map<String, Object?> args;

  bool get isRetryable =>
      code == ApiErrorCode.networkUnavailable ||
      code == ApiErrorCode.timeout ||
      code == ApiErrorCode.serverError ||
      code == ApiErrorCode.rateLimited;

  bool get isAuthRelated =>
      code == ApiErrorCode.unauthorized || code == ApiErrorCode.forbidden;

  bool get isRevisionConflict => code == ApiErrorCode.conflictRevision;

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'message': message,
    if (statusCode != null) 'statusCode': statusCode,
    if (requestId != null) 'requestId': requestId,
    if (fieldErrors.isNotEmpty) 'fieldErrors': fieldErrors,
    if (args.isNotEmpty) 'args': args,
  };

  factory ApiFailure.fromJson(Map<String, Object?> json) {
    final rawCode = json['code'];
    final rawMessage = json['message'];
    final rawFields = json['fieldErrors'];
    return ApiFailure(
      code: rawCode is String && rawCode.isNotEmpty
          ? rawCode
          : ApiErrorCode.serverError,
      message: rawMessage is String && rawMessage.isNotEmpty
          ? rawMessage
          : 'server error',
      statusCode: json['statusCode'] is int ? json['statusCode']! as int : null,
      requestId: json['requestId'] is String
          ? json['requestId']! as String
          : null,
      fieldErrors: rawFields is Map
          ? <String, String>{
              for (final entry in rawFields.entries)
                if (entry.key is String && entry.value is String)
                  entry.key as String: entry.value as String,
            }
          : const <String, String>{},
    );
  }

  ApiFailure copyWith({
    String? code,
    String? message,
    int? statusCode,
    String? requestId,
    Map<String, String>? fieldErrors,
    Map<String, Object?>? args,
  }) => ApiFailure(
    code: code ?? this.code,
    message: message ?? this.message,
    statusCode: statusCode ?? this.statusCode,
    requestId: requestId ?? this.requestId,
    fieldErrors: fieldErrors ?? this.fieldErrors,
    args: args ?? this.args,
  );

  @override
  String toString() {
    final status = statusCode == null ? '' : ' [$statusCode]';
    final path = args['path'];
    final location = path is String ? ' at $path' : '';
    return 'ApiFailure($code)$status$location: $message';
  }
}

abstract final class ApiErrorCode {
  static const String unauthorized = 'unauthorized';

  static const String forbidden = 'forbidden';

  static const String conflictRevision = 'conflict_revision';

  static const String idempotencyConflict = 'idempotency_conflict';

  static const String validationFailed = 'validation_failed';

  static const String notFound = 'not_found';

  static const String rateLimited = 'rate_limited';

  static const String serverError = 'server_error';

  static const String networkUnavailable = 'network_unavailable';

  static const String timeout = 'timeout';

  static const String invalidResponse = 'invalid_response';

  static const String invalidMoney = 'invalid_money';

  static const String aiDisabled = 'ai_disabled';

  static const String aiNoProposal = 'ai_no_proposal';

  static const Set<String> all = <String>{
    unauthorized,
    forbidden,
    conflictRevision,
    idempotencyConflict,
    validationFailed,
    notFound,
    rateLimited,
    serverError,
    networkUnavailable,
    timeout,
    invalidResponse,
    invalidMoney,
    aiDisabled,
    aiNoProposal,
  };
}
