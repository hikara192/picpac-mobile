import 'package:collection/collection.dart';
import 'package:design_core/design_core.dart';

import 'failure.dart';
import 'money.dart';

typedef JsonMap = Map<String, Object?>;

mixin ValueJson {
  Map<String, Object?> toJson();

  @override
  bool operator ==(Object other) =>
      other is ValueJson &&
      other.runtimeType == runtimeType &&
      const DeepCollectionEquality().equals(other.toJson(), toJson());

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(toJson()));

  @override
  String toString() => '$runtimeType(${toJson()})';
}

abstract final class J {
  static JsonMap readObject(Object? value, String path) {
    if (value == null) throw _missing(path, 'object');
    if (value is JsonMap) return value;
    if (value is Map) {
      return <String, Object?>{
        for (final entry in value.entries)
          if (entry.key is String) entry.key as String: entry.value,
      };
    }
    throw _invalid(path, 'object', value);
  }

  static List<Object?> readList(Object? value, String path) {
    if (value == null) throw _missing(path, 'array');
    if (value is List<Object?>) return value;
    if (value is List) return value.cast<Object?>();
    throw _invalid(path, 'array', value);
  }

  static String readString(Object? value, String path) {
    if (value == null) throw _missing(path, 'string');
    if (value is String) return value;
    throw _invalid(path, 'string', value);
  }

  static String? readStringOrNull(Object? value, String path) =>
      value == null ? null : readString(value, path);

  static String readId(Object? value, String path) {
    final raw = readString(value, path);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw ApiFailure(
        code: ApiErrorCode.invalidResponse,
        message: 'identifier must not be empty',
        args: <String, Object?>{'path': path},
      );
    }
    return trimmed;
  }

  static String? readIdOrNull(Object? value, String path) {
    final raw = readStringOrNull(value, path);
    if (raw == null) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int readInt(Object? value, String path) {
    if (value == null) throw _missing(path, 'int');
    return switch (value) {
      final int integer => integer,
      final double real when real.isFinite && real == real.truncateToDouble() =>
        real.toInt(),
      _ => throw _invalid(path, 'int', value),
    };
  }

  static int? readIntOrNull(Object? value, String path) =>
      value == null ? null : readInt(value, path);

  static double readDouble(Object? value, String path) {
    if (value == null) throw _missing(path, 'double');
    final result = switch (value) {
      final int integer => integer.toDouble(),
      final double real => real,
      _ => null,
    };
    if (result == null || !result.isFinite) {
      throw _invalid(path, 'finite double', value);
    }
    return result;
  }

  static double? readDoubleOrNull(Object? value, String path) =>
      value == null ? null : readDouble(value, path);

  static bool readBool(Object? value, String path) {
    if (value == null) throw _missing(path, 'bool');
    if (value is bool) return value;
    throw _invalid(path, 'bool', value);
  }

  static bool readBoolOr(
    Object? value,
    String path, {
    required bool fallback,
  }) => value == null ? fallback : readBool(value, path);

  static DateTime readDate(Object? value, String path) {
    final raw = readString(value, path);
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      throw ApiFailure(
        code: ApiErrorCode.invalidResponse,
        message: 'expected an ISO-8601 timestamp',
        args: <String, Object?>{'path': path, 'value': raw},
      );
    }
    return parsed.toUtc();
  }

  static DateTime? readDateOrNull(Object? value, String path) =>
      value == null ? null : readDate(value, path);

  static Money readMoney(
    Object? value,
    String path, {
    bool allowNegative = true,
  }) => Money.fromJson(value, path, allowNegative: allowNegative);

  static T readEnum<T>(
    Object? value,
    String path, {
    required List<T> values,
    required String Function(T value) wire,
    required T fallback,
  }) {
    if (value == null) return fallback;
    final raw = readString(value, path);
    for (final candidate in values) {
      if (wire(candidate) == raw) return candidate;
    }
    return fallback;
  }

  static List<String> readStringList(Object? value, String path) {
    final list = readList(value, path);
    return <String>[
      for (var i = 0; i < list.length; i++) readString(list[i], '$path[$i]'),
    ];
  }

  static Map<String, String> readStringMap(Object? value, String path) {
    final map = readObject(value, path);
    return <String, String>{
      for (final entry in map.entries)
        entry.key: readString(entry.value, '$path.${entry.key}'),
    };
  }

  static ApiFailure _missing(String path, String expected) => ApiFailure(
    code: ApiErrorCode.invalidResponse,
    message: 'required field is missing',
    args: <String, Object?>{'path': path, 'expected': expected},
  );

  static ApiFailure _invalid(String path, String expected, Object? value) =>
      ApiFailure(
        code: ApiErrorCode.invalidResponse,
        message: 'expected $expected, got ${_describe(value)}',
        args: <String, Object?>{'path': path, 'expected': expected},
      );

  static String _describe(Object? value) => switch (value) {
    null => 'null',
    String() => 'string',
    int() => 'int',
    double() => 'double',
    bool() => 'bool',
    List() => 'array',
    Map() => 'object',
    _ => '${value.runtimeType}',
  };
}

Result<T> decodeJson<T>(Object? raw, T Function(JsonMap json) parse) {
  try {
    return Ok<T>(parse(J.readObject(raw, r'$')));
  } on ApiFailure catch (error) {
    return Err<T>(error);
  } on DesignFormatException catch (error) {
    return Err<T>(
      ApiFailure(
        code: ApiErrorCode.invalidResponse,
        message: error.message,
        args: <String, Object?>{'path': error.path ?? r'$', 'code': error.code},
      ),
    );
  } catch (error) {
    return Err<T>(
      ApiFailure(
        code: ApiErrorCode.invalidResponse,
        message: 'unexpected payload shape',
        args: <String, Object?>{'path': r'$', 'error': '$error'},
      ),
    );
  }
}

Result<List<T>> decodeJsonList<T>(
  Object? raw,
  T Function(JsonMap json, String path) parse,
) {
  try {
    final list = J.readList(raw, r'$');
    return Ok<List<T>>(<T>[
      for (var i = 0; i < list.length; i++)
        parse(J.readObject(list[i], '\$[$i]'), '\$[$i]'),
    ]);
  } on ApiFailure catch (error) {
    return Err<List<T>>(error);
  } on DesignFormatException catch (error) {
    return Err<List<T>>(
      ApiFailure(
        code: ApiErrorCode.invalidResponse,
        message: error.message,
        args: <String, Object?>{'path': error.path ?? r'$', 'code': error.code},
      ),
    );
  } catch (error) {
    return Err<List<T>>(
      ApiFailure(
        code: ApiErrorCode.invalidResponse,
        message: 'unexpected payload shape',
        args: <String, Object?>{'path': r'$', 'error': '$error'},
      ),
    );
  }
}
