import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/core/validation/phone.dart';

void main() {
  group('E.164', () {
    test('Беларусь: +375, 80 и национальный номер', () {
      expect(
        PhoneNumber.tryParse('+375 (29) 123-45-67')?.e164,
        '+375291234567',
      );
      expect(PhoneNumber.tryParse('80 29 123-45-67')?.e164, '+375291234567');
      expect(PhoneNumber.tryParse('80251234567')?.e164, '+375251234567');
      expect(PhoneNumber.tryParse('33 123 45 67')?.e164, '+375331234567');
      expect(PhoneNumber.tryParse('44 1234567')?.e164, '+375441234567');
    });

    test('Россия: +7 и 8', () {
      expect(PhoneNumber.tryParse('+7 999 123-45-67')?.e164, '+79991234567');
      expect(PhoneNumber.tryParse('8 999 123 45 67')?.e164, '+79991234567');
      expect(PhoneNumber.tryParse('9991234567')?.e164, '+79991234567');
    });

    test('мусор отклоняется', () {
      expect(PhoneNumber.tryParse('1234567'), isNull);
      expect(PhoneNumber.tryParse(''), isNull);
      expect(PhoneNumber.tryParse('не телефон'), isNull);
      expect(PhoneNumber.tryParse('+375 17 123-45-67'), isNull);
      expect(PhoneNumber.tryParse('+1 555 0100'), isNull);
    });
  });

  group('маска ввода', () {
    test('белорусский номер группируется по мере ввода', () {
      expect(PhoneNumber.format('80'), '80');
      expect(PhoneNumber.format('8029'), '80 (29');
      expect(PhoneNumber.format('8029123'), '80 (29) 123');
      expect(PhoneNumber.format('80291234567'), '80 (29) 123-45-67');
      expect(PhoneNumber.format('375291234567'), '+375 (29) 123-45-67');
    });

    test('российский номер группируется по мере ввода', () {
      expect(PhoneNumber.format('79991234567'), '+7 (999) 123-45-67');
      expect(PhoneNumber.format('89991234567'), '8 (999) 123-45-67');
    });
  });
}
