import '../document/design_format_exception.dart';

abstract final class JsonRead {
  static Map<String, Object?> object(Object? value, String path) {
    if (value == null) {
      throw _missing(path);
    }
    if (value is Map<String, Object?>) return value;
    if (value is Map) {
      return <String, Object?>{
        for (final entry in value.entries)
          if (entry.key is String) entry.key as String: entry.value,
      };
    }
    throw _type(path, 'object', value);
  }

  static List<Object?> array(Object? value, String path) {
    if (value == null) throw _missing(path);
    if (value is List<Object?>) return value;
    if (value is List) return value.cast<Object?>();
    throw _type(path, 'array', value);
  }

  static String id(Object? value, String path) {
    final raw = string(value, path);
    if (raw.trim().isEmpty) {
      throw DesignFormatException(
        code: DesignFormatErrorCode.invalidValue,
        message: 'expected a non-empty identifier',
        path: path,
      );
    }
    return raw;
  }

  static String? optId(Object? value, String path) {
    if (value == null) return null;
    final raw = string(value, path);
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String string(Object? value, String path) {
    if (value == null) throw _missing(path);
    if (value is String) return value;
    throw _type(path, 'string', value);
  }

  static String? optString(Object? value, String path) {
    if (value == null) return null;
    if (value is String) return value;
    throw _type(path, 'string', value);
  }

  static double number(Object? value, String path) {
    if (value == null) throw _missing(path);
    final result = switch (value) {
      final int i => i.toDouble(),
      final double d => d,
      _ => null,
    };
    if (result == null) throw _type(path, 'number', value);
    if (!result.isFinite) {
      throw DesignFormatException(
        code: DesignFormatErrorCode.invalidValue,
        message: 'expected a finite number',
        path: path,
      );
    }
    return result;
  }

  static double? optNumber(Object? value, String path) =>
      value == null ? null : number(value, path);

  static int integer(Object? value, String path) {
    if (value == null) throw _missing(path);
    return switch (value) {
      final int i => i,
      final double d when d.isFinite && d == d.truncateToDouble() => d.toInt(),
      _ => throw DesignFormatException(
        code: DesignFormatErrorCode.invalidType,
        message: 'expected an integer, got ${_describe(value)}',
        path: path,
      ),
    };
  }

  static int? optInteger(Object? value, String path) =>
      value == null ? null : integer(value, path);

  static bool boolean(Object? value, String path) {
    if (value == null) throw _missing(path);
    if (value is bool) return value;
    throw _type(path, 'boolean', value);
  }

  static bool booleanOr(Object? value, String path, {required bool fallback}) =>
      value == null ? fallback : boolean(value, path);

  static Map<String, String> stringMap(Object? value, String path) {
    final raw = object(value, path);
    return <String, String>{
      for (final entry in raw.entries)
        entry.key: string(entry.value, '$path.${entry.key}'),
    };
  }

  static List<String> stringList(Object? value, String path) {
    final raw = array(value, path);
    return <String>[
      for (var i = 0; i < raw.length; i++) string(raw[i], '$path[$i]'),
    ];
  }

  static List<String> idList(Object? value, String path) {
    final raw = array(value, path);
    return <String>[
      for (var i = 0; i < raw.length; i++) id(raw[i], '$path[$i]'),
    ];
  }

  static DesignFormatException _missing(String path) => DesignFormatException(
    code: DesignFormatErrorCode.missingField,
    message: 'required field is missing',
    path: path,
  );

  static DesignFormatException _type(
    String path,
    String expected,
    Object? got,
  ) => DesignFormatException(
    code: DesignFormatErrorCode.invalidType,
    message: 'expected $expected, got ${_describe(got)}',
    path: path,
  );

  static String _describe(Object? value) => switch (value) {
    null => 'null',
    String() => 'string',
    int() => 'int',
    double() => 'double',
    bool() => 'bool',
    List() => 'array',
    Map() => 'object',
    _ => value.runtimeType.toString(),
  };
}
