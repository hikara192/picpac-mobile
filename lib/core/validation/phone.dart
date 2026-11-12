library;

import 'package:flutter/services.dart';

final class PhoneNumber {
  const PhoneNumber._(this.e164);

  final String e164;

  static const Set<String> _byMobilePrefixes = <String>{'25', '29', '33', '44'};

  static const int _byNationalLength = 9;
  static const int _ruNationalLength = 10;

  static PhoneNumber? tryParse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    if (text.startsWith('+')) {
      if (digits.startsWith('375')) return _belarus(digits.substring(3));
      if (digits.startsWith('7')) return _russia(digits.substring(1));
      return null;
    }
    if (digits.startsWith('80')) return _belarus(digits.substring(2));
    if (digits.startsWith('8')) return _russia(digits.substring(1));
    if (digits.length == _byNationalLength) return _belarus(digits);
    if (digits.length == _ruNationalLength && digits.startsWith('9')) {
      return _russia(digits);
    }
    return null;
  }

  static PhoneNumber? _belarus(String national) {
    if (national.length != _byNationalLength) return null;
    if (!_byMobilePrefixes.contains(national.substring(0, 2))) return null;
    return PhoneNumber._('+375$national');
  }

  static PhoneNumber? _russia(String national) {
    if (national.length != _ruNationalLength) return null;
    if (!national.startsWith('9')) return null;
    return PhoneNumber._('+7$national');
  }

  static String format(String digits, {bool international = false}) {
    if (digits.isEmpty) return international ? '+' : '';
    if (digits.startsWith('375')) {
      return '+375${_belarusNational(digits.substring(3))}';
    }
    if (digits.startsWith('80')) {
      return '80${_belarusNational(digits.substring(2))}';
    }
    if (digits.startsWith('8')) {
      return '8${_russiaNational(digits.substring(1))}';
    }
    if (digits.startsWith('7')) {
      return '+7${_russiaNational(digits.substring(1))}';
    }
    if (digits.length <= 2) return digits;
    return _belarusNational(digits).trimLeft();
  }

  static String _belarusNational(String raw) {
    final digits = raw.length > _byNationalLength
        ? raw.substring(0, _byNationalLength)
        : raw;
    if (digits.isEmpty) return '';
    if (digits.length <= 2) return ' ($digits';
    final rest = digits.substring(2);
    final buffer = StringBuffer(' (${digits.substring(0, 2)})');
    if (rest.isNotEmpty) {
      buffer.write(' ${_take(rest, 0, 3)}');
    }
    if (rest.length > 3) {
      final tail = rest.substring(3);
      buffer.write('-${_take(tail, 0, 2)}');
      if (tail.length > 2) buffer.write('-${tail.substring(2)}');
    }
    return buffer.toString();
  }

  static String _russiaNational(String raw) {
    final digits = raw.length > _ruNationalLength
        ? raw.substring(0, _ruNationalLength)
        : raw;
    if (digits.isEmpty) return '';
    if (digits.length <= 3) return ' ($digits';
    final rest = digits.substring(3);
    final buffer = StringBuffer(' (${digits.substring(0, 3)})');
    if (rest.isNotEmpty) buffer.write(' ${_take(rest, 0, 3)}');
    if (rest.length > 3) {
      final tail = rest.substring(3);
      buffer.write('-${_take(tail, 0, 2)}');
      if (tail.length > 2) buffer.write('-${tail.substring(2)}');
    }
    return buffer.toString();
  }

  static String _take(String source, int start, int length) {
    final end = start + length;
    return source.substring(start, end > source.length ? source.length : end);
  }
}

class PhoneInputFormatter extends TextInputFormatter {
  const PhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final formatted = PhoneNumber.format(
      digits.length > 12 ? digits.substring(0, 12) : digits,
      international: newValue.text.trimLeft().startsWith('+'),
    );
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
