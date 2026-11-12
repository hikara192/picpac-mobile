import 'package:api_contract/api_contract.dart';

final class ApiException implements Exception {
  const ApiException(
    this.statusCode,
    this.code,
    this.message, {
    this.fieldErrors = const <String, String>{},
    this.extra = const <String, Object?>{},
    this.headers = const <String, String>{},
  });

  factory ApiException.unauthorized([String? message]) => ApiException(
    401,
    ApiErrorCode.unauthorized,
    message ?? 'authentication is required',
  );

  factory ApiException.forbidden([String? message]) =>
      ApiException(403, ApiErrorCode.forbidden, message ?? 'access is denied');

  factory ApiException.notFound([String? message]) =>
      ApiException(404, ApiErrorCode.notFound, message ?? 'object not found');

  factory ApiException.validation(
    String message, {
    Map<String, String> fieldErrors = const <String, String>{},
  }) => ApiException(
    422,
    ApiErrorCode.validationFailed,
    message,
    fieldErrors: fieldErrors,
  );

  factory ApiException.rateLimited(Duration retryAfter, [String? message]) {
    final seconds = retryAfter.inSeconds < 1 ? 1 : retryAfter.inSeconds;
    return ApiException(
      429,
      ApiErrorCode.rateLimited,
      message ?? 'too many attempts; try again in $seconds s',
      extra: <String, Object?>{'retryAfterSeconds': seconds},
      headers: <String, String>{'retry-after': '$seconds'},
    );
  }

  factory ApiException.conflict(
    String code,
    String message, {
    Map<String, Object?> extra = const <String, Object?>{},
  }) => ApiException(409, code, message, extra: extra);

  final int statusCode;

  final String code;

  final String message;

  final Map<String, String> fieldErrors;

  final Map<String, Object?> extra;

  final Map<String, String> headers;

  Map<String, Object?> toJson(String requestId) => <String, Object?>{
    'code': code,
    'message': message,
    'statusCode': statusCode,
    'requestId': requestId,
    if (fieldErrors.isNotEmpty) 'fieldErrors': fieldErrors,
    ...extra,
  };

  @override
  String toString() => 'ApiException($statusCode $code): $message';
}

abstract final class Failures {
  static const ApiException idempotencyKeyRequired = ApiException(
    400,
    'idempotency_key_required',
    'the Idempotency-Key header is required for this operation',
  );

  static const ApiException preconditionRequired = ApiException(
    428,
    'precondition_required',
    'the If-Match header with the current revision is required',
  );

  static const ApiException invalidJson = ApiException(
    422,
    ApiErrorCode.validationFailed,
    'the request body must be a valid JSON object',
  );

  static const ApiException payloadTooLarge = ApiException(
    413,
    'payload_too_large',
    'the request body exceeds the endpoint limit',
  );

  static const ApiException routeNotFound = ApiException(
    404,
    ApiErrorCode.notFound,
    'endpoint not found',
  );

  static const ApiException internal = ApiException(
    500,
    ApiErrorCode.serverError,
    'internal mock server error',
  );

  static const ApiException invalidSignature = ApiException(
    401,
    'invalid_signature',
    'the webhook signature is missing or invalid',
  );

  static const ApiException refundNeedsSupport = ApiException(
    403,
    'refund_requires_support',
    'refunds are issued by a support agent, not by the customer',
  );

  static const ApiException advanceNeedsSupport = ApiException(
    403,
    'advance_requires_support',
    'a customer can only cancel the order; other transitions need support',
  );
}
