import 'package:api_contract/api_contract.dart';
import 'package:intl/intl.dart';

final class MoneyFormatter {
  MoneyFormatter({String locale = 'ru'})
    : _numbers = NumberFormat.decimalPattern(locale);

  final NumberFormat _numbers;

  String format(
    Money money, {
    int minorUnitDigits = 2,
    String? currencySymbol,
    bool withCode = true,
  }) {
    final digits = minorUnitDigits.clamp(0, 3);
    final divisor = _pow10(digits);
    final whole = money.amountMinor.abs() ~/ divisor;
    final fraction = money.amountMinor.abs() % divisor;
    final buffer = StringBuffer();
    if (money.isRefund) buffer.write('−');
    buffer.write(_numbers.format(whole));
    if (digits > 0) {
      buffer
        ..write(',')
        ..write(fraction.toString().padLeft(digits, '0'));
    }
    final symbol = currencySymbol;
    if (symbol != null) {
      buffer
        ..write(' ')
        ..write(symbol);
    } else if (withCode) {
      buffer
        ..write(' ')
        ..write(money.currency);
    }
    return buffer.toString();
  }

  static int _pow10(int digits) {
    var result = 1;
    for (var i = 0; i < digits; i++) {
      result *= 10;
    }
    return result;
  }
}
