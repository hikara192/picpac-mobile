import 'package:api_contract/api_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/core/orders/cart_pricing.dart';

import 'support/fixtures.dart';

void main() {
  DesignDocument document({int sheets = 10, int planned = 0}) => DesignDocument(
    product: const DocumentProduct(id: 'photo_print', formatId: '10x15'),
    spreads: <Spread>[
      for (var index = 0; index < sheets; index++)
        Spread(
          id: 'sheet_${index + 1}',
          templateId: 'single_10x15',
          background: SpreadBackground.color('#FAF5ED'),
          slots: const <Slot>[Slot(id: 'main')],
        ),
    ],
    spreadsCount: planned == 0 ? sheets : planned,
  );

  group('единица цены выводится из формата', () {
    test('печать: лист', () {
      expect(pricingUnitOf(printFormat()), PricingUnit.sheet);
    });

    test('книга: разворот', () {
      expect(pricingUnitOf(bookFormat()), PricingUnit.spread);
    });
  });

  group('количество для POST /cart/items', () {
    test('печать отправляет число листов макета', () {
      expect(
        cartQuantityFor(format: printFormat(), document: document()),
        10,
        reason: 'сервер умножает цену листа на количество',
      );
    });

    test('печать: раскладка из 12 листов даёт quantity 12', () {
      expect(
        cartQuantityFor(format: printFormat(), document: document(sheets: 12)),
        12,
      );
    });

    test('печать без листов отправляет 1, а не 0', () {
      expect(
        cartQuantityFor(format: printFormat(), document: document(sheets: 0)),
        1,
      );
    });

    test('книга отправляет тираж, а не число разворотов', () {
      expect(
        cartQuantityFor(format: bookFormat(), document: document(sheets: 20)),
        1,
      );
      expect(
        cartQuantityFor(
          format: bookFormat(),
          document: document(sheets: 20),
          copies: 3,
        ),
        3,
      );
    });

    test('количество ограничено контрактом', () {
      expect(
        cartQuantityFor(format: printFormat(), document: document(sheets: 500)),
        maxCartQuantity,
      );
    });
  });

  group('единицы для POST /price', () {
    test('печать: spreadsCount равен количеству листов', () {
      expect(
        pricingUnits(format: printFormat(), quantity: 10, documentSpreads: 10),
        10,
      );
    });

    test('книга: spreadsCount берётся из документа', () {
      expect(
        pricingUnits(format: bookFormat(), quantity: 1, documentSpreads: 20),
        20,
      );
    });

    test('книга: слишком маленький макет поднимается до minSpreads', () {
      expect(
        pricingUnits(format: bookFormat(), quantity: 1, documentSpreads: 2),
        10,
      );
    });
  });

  test('число листов берётся из макета, затем из плана', () {
    expect(sheetCountOf(document(sheets: 10)), 10);
    expect(sheetCountOf(document(sheets: 0, planned: 6)), 6);
    expect(sheetCountOf(document(sheets: 0, planned: 0)), 1);
  });
}
