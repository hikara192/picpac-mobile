import 'dart:math' as math;

import 'failure.dart';
import 'json.dart';

final class Money with ValueJson {
  const Money({required this.amountMinor, required this.currency});

  const Money.zero(this.currency) : amountMinor = 0;

  final int amountMinor;

  final String currency;

  bool get isZero => amountMinor == 0;

  bool get isRefund => amountMinor < 0;

  Money get abs => Money(amountMinor: amountMinor.abs(), currency: currency);

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(
      amountMinor: amountMinor + other.amountMinor,
      currency: currency,
    );
  }

  Money operator *(int factor) =>
      Money(amountMinor: amountMinor * factor, currency: currency);

  bool isLessThan(Money other) {
    _assertSameCurrency(other);
    return amountMinor < other.amountMinor;
  }

  String toMinorString() => amountMinor.toString();

  String format({
    String? locale,
    String? currencySymbol,
    int fractionDigits = 2,
    int minorUnitDigits = 2,
  }) {
    if (fractionDigits < 0) {
      throw ArgumentError.value(
        fractionDigits,
        'fractionDigits',
        'must be >= 0',
      );
    }
    if (minorUnitDigits < 0) {
      throw ArgumentError.value(
        minorUnitDigits,
        'minorUnitDigits',
        'must be >= 0',
      );
    }
    final separators = _Separators.of(locale);
    final negative = amountMinor < 0;
    final absolute = amountMinor.abs();
    final drop = minorUnitDigits - fractionDigits;
    final displayAmount = drop > 0
        ? (absolute / math.pow(10, drop)).round()
        : absolute * math.pow(10, -drop).toInt();
    final scale = math.pow(10, fractionDigits).toInt();
    final whole = displayAmount ~/ scale;
    final fraction = displayAmount % scale;
    final sign = negative && displayAmount != 0 ? '-' : '';
    final grouped = _groupDigits(whole.toString(), separators.group);
    final decimals = fractionDigits == 0
        ? ''
        : '${separators.decimal}'
              '${fraction.toString().padLeft(fractionDigits, '0')}';
    final symbol = currencySymbol ?? currency;
    return '$sign$grouped$decimals $symbol';
  }

  factory Money.fromJson(
    Object? json,
    String path, {
    bool allowNegative = true,
  }) {
    final map = J.readObject(json, path);
    final currency = J.readId(map['currency'], '$path.currency');
    final raw = map['amountMinor'];
    if (raw is! int) {
      throw ApiFailure(
        code: ApiErrorCode.invalidMoney,
        message:
            'amountMinor must be an integer in minor units, got '
            '${raw.runtimeType}',
        args: <String, Object?>{'path': '$path.amountMinor', 'value': '$raw'},
      );
    }
    if (!allowNegative && raw < 0) {
      throw ApiFailure(
        code: ApiErrorCode.invalidMoney,
        message: 'amountMinor must not be negative here, got $raw',
        args: <String, Object?>{'path': '$path.amountMinor', 'value': raw},
      );
    }
    return Money(amountMinor: raw, currency: currency.toUpperCase());
  }

  factory Money.nonNegativeFromJson(Object? json, String path) =>
      Money.fromJson(json, path, allowNegative: false);

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'amountMinor': amountMinor,
    'currency': currency,
  };

  static Money parse(Object? json) => Money.fromJson(json, r'$');

  void _assertSameCurrency(Money other) {
    if (other.currency != currency) {
      throw ArgumentError.value(
        other.currency,
        'currency',
        'cannot combine $currency with ${other.currency}',
      );
    }
  }

  static String _groupDigits(String digits, String separator) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(separator);
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}

final class _Separators {
  const _Separators(this.group, this.decimal);

  final String group;
  final String decimal;

  static const _Separators _ru = _Separators('\u00A0', ',');
  static const _Separators _en = _Separators(',', '.');
  static const _Separators _neutral = _Separators('\u00A0', '.');

  static _Separators of(String? locale) {
    final language = (locale ?? '').toLowerCase().split(RegExp('[-_]')).first;
    return switch (language) {
      'ru' || 'be' || 'uk' => _ru,
      'en' => _en,
      _ => _neutral,
    };
  }
}
