import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> readArb(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  final ru = readArb('lib/l10n/app_ru.arb');
  final be = readArb('lib/l10n/app_be.arb');

  Set<String> messages(Map<String, dynamic> arb) =>
      arb.keys.where((String key) => !key.startsWith('@')).toSet();

  Set<String> placeholders(String message) =>
      RegExp(r'\{([A-Za-z_][A-Za-z0-9_]*)')
          .allMatches(message)
          .map((RegExpMatch match) => match.group(1)!)
          .toSet();

  test('ru и be содержат одинаковый набор ключей', () {
    final ruKeys = messages(ru);
    final beKeys = messages(be);
    expect(beKeys, isNotEmpty);
    expect(ruKeys.difference(beKeys), isEmpty, reason: 'нет в be');
    expect(beKeys.difference(ruKeys), isEmpty, reason: 'лишние в be');
  });

  test('каждый ключ шаблона объявляет атрибут @key', () {
    final missing = messages(
      ru,
    ).where((String key) => !ru.containsKey('@$key')).toList()..sort();
    expect(missing, isEmpty);
  });

  test('плейсхолдеры совпадают: подстановки и ICU-плюралы', () {
    final mismatched = <String>[];
    for (final key in messages(ru)) {
      if (!be.containsKey(key)) continue;
      final ruValue = ru[key] as String;
      final beValue = be[key] as String;
      if (placeholders(ruValue).join(',') != placeholders(beValue).join(',')) {
        mismatched.add(
          '$key: {${placeholders(ruValue).join(',')}} → '
          '{${placeholders(beValue).join(',')}}',
        );
      }
    }
    expect(mismatched, isEmpty);
  });

  test('плюралы объявляют все категории, которые видят ru и be', () {
    for (final key in messages(ru)) {
      final ruValue = ru[key] as String;
      if (!ruValue.contains(', plural,')) continue;
      expect(ruValue, contains('one{'), reason: '$key в ru');
      expect(ruValue, contains('few{'), reason: '$key в ru');
      expect(ruValue, contains('many{'), reason: '$key в ru');
      expect(ruValue, contains('other{'), reason: '$key в ru');
      final beValue = be[key] as String;
      expect(beValue, contains(', plural,'), reason: '$key в be');
      expect(beValue, contains('one{'), reason: '$key в be');
      expect(beValue, contains('few{'), reason: '$key в be');
      expect(beValue, contains('many{'), reason: '$key в be');
      expect(beValue, contains('other{'), reason: '$key в be');
    }
  });

  test('обе локали объявлены в своём ARB', () {
    expect(ru['@@locale'], 'ru');
    expect(be['@@locale'], 'be');
  });
}
