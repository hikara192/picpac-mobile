import 'package:api_contract/api_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:picpac_mobile/core/money_format.dart';
import 'package:picpac_mobile/core/presentation/format.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
    await initializeDateFormatting('be');
  });

  const String nbsp = '\u00A0';

  group('деньги: int minor units + ISO-код', () {
    test('ru: 1 234,50 BYN', () {
      final formatter = MoneyFormatter(locale: 'ru');
      expect(
        formatter.format(const Money(amountMinor: 123450, currency: 'BYN')),
        '1${nbsp}234,50 BYN',
      );
      expect(
        formatter.format(const Money(amountMinor: 520, currency: 'BYN')),
        '5,20 BYN',
      );
    });

    test('be: те же разделители, белорусская локаль', () {
      final formatter = MoneyFormatter(locale: 'be');
      expect(
        formatter.format(const Money(amountMinor: 123450, currency: 'BYN')),
        '1${nbsp}234,50 BYN',
      );
    });

    test('скидка не теряет знак и не уходит в double', () {
      final formatter = MoneyFormatter(locale: 'be');
      expect(
        formatter.format(const Money(amountMinor: -520, currency: 'BYN')),
        '−5,20 BYN',
      );
    });
  });

  group('даты по локали', () {
    final day = DateTime(2026, 11, 12, 14, 30);

    test('ru', () {
      final fmt = Fmt('ru');
      expect(fmt.date(day), '12 ноября 2026');
      expect(fmt.shortDate(day), '12 нояб.');
      expect(fmt.dateTime(day), '12 нояб., 14:30');
      expect(
        fmt.slot(DateTime(2026, 11, 12, 10), DateTime(2026, 11, 12, 12)),
        '12 нояб., 10:00–12:00',
      );
    });

    test('be', () {
      final fmt = Fmt('be');
      expect(fmt.date(day), '12 лістапада 2026');
      expect(fmt.shortDate(day), '12 ліс');
      expect(fmt.dateTime(day), '12 ліс, 14:30');
      expect(
        fmt.slot(DateTime(2026, 11, 12, 10), DateTime(2026, 11, 12, 12)),
        '12 ліс, 10:00–12:00',
      );
    });
  });

  group('миллиметры', () {
    test('без выдуманной точности, запятая в обеих локалях', () {
      expect(Fmt.millimetres(102), '102');
      expect(Fmt.millimetres(50.7, locale: 'be'), '50,7');
      expect(Fmt.millimetres(75.62, locale: 'ru'), '75,6');
    });
  });
}
