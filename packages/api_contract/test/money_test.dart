import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

ApiFailure _moneyFailure(Object? amountMinor) {
  try {
    Money.fromJson(<String, Object?>{
      'amountMinor': amountMinor,
      'currency': 'BYN',
    }, r'$.total');
  } on ApiFailure catch (error) {
    return error;
  }
  fail('Money.fromJson accepted $amountMinor');
}

void main() {
  group('money', () {
    test('keeps integer minor units through JSON', () {
      const money = Money(amountMinor: 9290, currency: 'BYN');
      final decoded = roundTrip(
        money.toJson(),
        (json) => Money.fromJson(json, r'$'),
      );
      expect(decoded, money);
      expect(decoded.amountMinor, 9290);
      expect(decoded.toMinorString(), '9290');
      expect(decoded.isZero, isFalse);
      expect(decoded.isRefund, isFalse);
    });

    test('rejects a decimal amount as invalid_money', () {
      final failure = _moneyFailure(92.9);
      expect(failure.code, ApiErrorCode.invalidMoney);
      expect(failure.args['path'], r'$.total.amountMinor');
    });

    test('rejects a numeric string with a separator', () {
      expect(_moneyFailure('92,90').code, ApiErrorCode.invalidMoney);
      expect(_moneyFailure('92.90').code, ApiErrorCode.invalidMoney);
      expect(_moneyFailure('9290').code, ApiErrorCode.invalidMoney);
    });

    test('rejects a negative amount where refunds are not allowed', () {
      final failure = () {
        try {
          Money.nonNegativeFromJson(<String, Object?>{
            'amountMinor': -130,
            'currency': 'BYN',
          }, r'$.amount');
        } on ApiFailure catch (error) {
          return error;
        }
        fail('non-negative money accepted a refund amount');
      }();
      expect(failure.code, ApiErrorCode.invalidMoney);
    });

    test('sums and multiplies without losing a minor unit', () {
      const a = Money(amountMinor: 130, currency: 'BYN');
      const b = Money(amountMinor: 45, currency: 'BYN');
      expect((a + b).amountMinor, 175);
      expect((a * 10).amountMinor, 1300);
      expect(a.isLessThan(a + b), isTrue);
      expect(a.abs.amountMinor, 130);
    });

    test('refuses to combine different currencies', () {
      const byn = Money(amountMinor: 100, currency: 'BYN');
      const rub = Money(amountMinor: 100, currency: 'RUB');
      expect(() => byn + rub, throwsArgumentError);
      expect(() => byn.isLessThan(rub), throwsArgumentError);
    });

    test('formats deterministically per locale without intl', () {
      const money = Money(amountMinor: 123456, currency: 'BYN');
      expect(money.format(locale: 'ru'), '1\u00A0234,56 BYN');
      expect(money.format(locale: 'be-BY'), '1\u00A0234,56 BYN');
      expect(money.format(locale: 'en'), '1,234.56 BYN');
      expect(money.format(locale: 'en', currencySymbol: 'Br'), '1,234.56 Br');
      expect(money.format(locale: 'en', fractionDigits: 0), '1,235 BYN');
      expect(
        const Money(amountMinor: -130, currency: 'BYN').format(locale: 'en'),
        '-1.30 BYN',
      );
    });

    test('equality is value-based through JSON', () {
      const a = Money(amountMinor: 100, currency: 'BYN');
      const b = Money(amountMinor: 100, currency: 'BYN');
      const c = Money(amountMinor: 100, currency: 'RUB');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
