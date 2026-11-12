import '../core/failure.dart';

final class DesignFormatException implements Failure {
  const DesignFormatException({
    required this.code,
    required this.message,
    this.path,
    this.args = const <String, Object?>{},
  });

  @override
  final String code;

  @override
  final String message;

  final String? path;

  @override
  final Map<String, Object?> args;

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'message': message,
    if (path != null) 'path': path,
    if (args.isNotEmpty) 'args': args,
  };

  @override
  String toString() {
    final location = path == null ? '' : ' at $path';
    return 'DesignFormatException($code$location): $message';
  }
}

abstract final class DesignFormatErrorCode {
  static const String schemaTooNew = 'schema_too_new';

  static const String schemaUnsupported = 'schema_unsupported';

  static const String missingField = 'missing_field';

  static const String invalidType = 'invalid_type';

  static const String invalidValue = 'invalid_value';

  static const String outOfRange = 'out_of_range';

  static const String duplicateId = 'duplicate_id';

  static const String invalidReference = 'invalid_reference';
}
