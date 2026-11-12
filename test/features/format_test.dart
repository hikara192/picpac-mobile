import 'package:api_contract/api_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/core/presentation/format.dart';

void main() {
  test('миллиметры не выдумывают точность и пишутся с запятой', () {
    expect(Fmt.millimetres(102), '102');
    expect(Fmt.millimetres(50.7), '50,7');
    expect(Fmt.millimetres(75.62), '75,6');
    expect(Fmt.millimetres(0), '0');
  });

  test('деньги форматируются из minor units по локали', () {
    const amount = Money(amountMinor: 520, currency: 'BYN');
    expect(Fmt('ru').money(amount), '5,20 BYN');
    expect(
      Fmt('ru').money(const Money(amountMinor: 1300, currency: 'BYN')),
      '13,00 BYN',
    );
  });
}
