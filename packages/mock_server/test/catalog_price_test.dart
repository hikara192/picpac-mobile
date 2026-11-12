import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  late MockApi api;

  setUp(() => api = MockApi());

  group('catalogue', () {
    test(
      'serves products, formats and templates parsable by the contract',
      () async {
        final response = await api.call('GET', '/v1/catalog');
        expect(response.status, 200, reason: response.text);
        final catalog = CatalogResponse.fromJson(response.object);
        expect(catalog.currency, 'BYN');
        expect(catalog.region, 'BY');
        expect(catalog.products, isNotEmpty);

        final prints = catalog.products.firstWhere(
          (product) => product.id == 'photo_print',
        );
        final format = prints.formats.firstWhere((f) => f.id == '10x15');
        expect(format.widthMm, 102);
        expect(format.heightMm, 152);
        expect(format.dpi, 300);
        expect(format.etaDays, 2);
        expect(format.minPhotos, 1);
        expect(format.maxPhotos, 4);
        expect(
          format.templates.map((template) => template.id),
          containsAll(<String>[
            'single_10x15',
            'duo_10x15',
            'quad_10x15',
            'single_3x4',
          ]),
        );
        expect(format.templates.first.slots.single.rect.w, 1);
        expect(prints.minPrice!.amountMinor, 130);
        expect(prints.minPrice!.currency, 'BYN');
      },
    );

    test('serves a single product and its formats', () async {
      final product = await api.call('GET', '/v1/catalog/photo_print');
      expect(product.status, 200);
      expect(Product.fromJson(product.object).id, 'photo_print');

      final formats = await api.call('GET', '/v1/catalog/photo_print/formats');
      expect(formats.status, 200);
      final parsed = decodeJsonList(
        formats.json,
        (json, path) => ProductFormat.fromJson(json, path),
      );
      expect(parsed.isOk, isTrue, reason: '${parsed.failureOrNull}');
      expect(parsed.requireValue.map((f) => f.id), contains('15x20'));

      final missing = await api.call('GET', '/v1/catalog/unknown');
      expectError(missing, 404, ApiErrorCode.notFound);
    });

    test(
      'books carry spread limits, cover geometry and photo bounds',
      () async {
        final response = await api.call('GET', '/v1/catalog/photo_book_lite');
        final product = Product.fromJson(response.object);
        final format = product.formats.single;
        expect(format.minSpreads, 24);
        expect(format.maxSpreads, 160);
        expect(format.spreadStep, 2);
        expect(format.spreadWidthMm, 203);
        expect(format.coverWidthMm, 454);
        expect(format.minPhotos, 25);
        expect(format.maxPhotos, 400);
      },
    );
  });

  group('price', () {
    test('computes unit × quantity with integer minor units', () async {
      final response = await api.price(spreadsCount: 10);
      expect(response.status, 200, reason: response.text);
      final quote = PriceQuote.fromJson(response.object);
      expect(quote.total.amountMinor, 1300);
      expect(quote.total.currency, 'BYN');
      expect(quote.productionMinor, 1300);
      expect(quote.deliveryMinor, 0);
      expect(quote.etaDays, 2);
      expect(quote.canOrder, isTrue);
      expect(quote.breakdown.single.code, 'product');
      expect(quote.breakdown.single.amount.amountMinor, 1300);
    });

    test('applies TEST10 as a negative server-side line', () async {
      final response = await api.price(spreadsCount: 10, promoCode: 'TEST10');
      final quote = PriceQuote.fromJson(response.object);
      expect(quote.promoApplied, 'TEST10');
      expect(quote.total.amountMinor, 1170);
      expect(quote.productionMinor, 1170);
      final promo = quote.breakdown.singleWhere((line) => line.code == 'promo');
      expect(promo.amount.amountMinor, -130);
      expect(promo.amount.isRefund, isTrue);
    });

    test('PIC100 makes the whole order free', () async {
      final response = await api.price(spreadsCount: 10, promoCode: 'PIC100');
      final quote = PriceQuote.fromJson(response.object);
      expect(quote.total.amountMinor, 0);
      expect(quote.isFree, isTrue);
      expect(quote.promoApplied, 'PIC100');
      expect(quote.breakdown.any((line) => line.code == 'promo'), isTrue);
    });

    test('rejects an unknown promo code with a dedicated code', () async {
      final response = await api.price(promoCode: 'NOPE');
      expectError(response, 422, 'promo_unknown');
      expect(fieldErrors(response)['promoCode'], 'promo_unknown');
    });

    test('rejects an unknown format and option value', () async {
      final unknownFormat = await api.call(
        'POST',
        '/v1/price',
        body: <String, Object?>{
          'productId': 'photo_print',
          'formatId': '99x99',
        },
      );
      expectError(unknownFormat, 422, ApiErrorCode.validationFailed);
      expect(fieldErrors(unknownFormat)['formatId'], 'unknown_format');

      final unknownOption = await api.call(
        'POST',
        '/v1/price',
        body: <String, Object?>{
          'productId': 'photo_print',
          'formatId': '10x15',
          'spreadsCount': 1,
          'options': <String, String>{'paper': 'holographic'},
        },
      );
      expectError(unknownOption, 422, ApiErrorCode.validationFailed);
      expect(fieldErrors(unknownOption)['options.paper'], 'unknown_value');
    });

    test('adds delivery, free-from threshold and ETA', () async {
      final belowThreshold = await api.price(
        spreadsCount: 10,
        delivery: <String, Object?>{
          'kind': 'post',
          'optionId': 'belpochta',
          'address': 'Минск, ул. Примерная, 1',
        },
      );
      final below = PriceQuote.fromJson(belowThreshold.object);
      expect(below.deliveryMinor, 690);
      expect(below.total.amountMinor, 1990);
      expect(below.etaDays, 5); // 2 production + 3 delivery
      expect(below.breakdown.last.code, 'delivery');

      final aboveThreshold = await api.price(
        spreadsCount: 200, // 260.00 BYN >= 150.00 BYN
        delivery: <String, Object?>{
          'kind': 'post',
          'optionId': 'belpochta',
          'address': 'Минск, ул. Примерная, 1',
        },
      );
      final above = PriceQuote.fromJson(aboveThreshold.object);
      expect(above.deliveryMinor, 0);
      expect(above.total.amountMinor, 26000);
    });

    test(
      'rejects pickup without a point and delivery without an address',
      () async {
        final pickup = await api.price(
          spreadsCount: 1,
          delivery: <String, Object?>{
            'kind': 'pickup',
            'optionId': 'pickup_main',
          },
        );
        expectError(pickup, 422, ApiErrorCode.validationFailed);
        expect(fieldErrors(pickup)['delivery.pointId'], 'unknown_point');

        final courier = await api.price(
          spreadsCount: 1,
          delivery: <String, Object?>{
            'kind': 'courier',
            'optionId': 'courier_minsk',
          },
        );
        expectError(courier, 422, ApiErrorCode.validationFailed);
        expect(fieldErrors(courier)['delivery.address'], 'required');
      },
    );

    test('prices a book by spreads and enforces the spread step', () async {
      final book = await api.call(
        'POST',
        '/v1/price',
        body: <String, Object?>{
          'productId': 'photo_book_classic',
          'formatId': '20x20',
          'spreadsCount': 11,
        },
      );
      expect(book.status, 200, reason: book.text);
      final quote = PriceQuote.fromJson(book.object);
      expect(quote.total.amountMinor, 8400);
      expect(quote.etaDays, 3);

      final badStep = await api.call(
        'POST',
        '/v1/price',
        body: <String, Object?>{
          'productId': 'photo_book_lite',
          'formatId': '20x20',
          'spreadsCount': 25,
        },
      );
      expectError(badStep, 422, ApiErrorCode.validationFailed);
      expect(fieldErrors(badStep)['spreadsCount'], 'invalid_step');
    });

    test('PIC100 covers delivery too, so the total is exactly zero', () async {
      final response = await api.price(
        spreadsCount: 1,
        promoCode: 'PIC100',
        delivery: <String, Object?>{
          'kind': 'ems',
          'optionId': 'ems',
          'address': 'Минск, ул. Примерная, 1',
        },
      );
      final quote = PriceQuote.fromJson(response.object);
      expect(quote.deliveryMinor, 2090);
      expect(quote.total.amountMinor, 0);
      expect(
        quote.breakdown
            .singleWhere((line) => line.code == 'promo')
            .amount
            .amountMinor,
        -2220,
      );
      expect(
        quote.breakdown
            .singleWhere((line) => line.code == 'delivery')
            .amount
            .amountMinor,
        2090,
      );
    });

    test('rejects a photo count outside the template capacity', () async {
      final response = await api.call(
        'POST',
        '/v1/price',
        body: <String, Object?>{
          'productId': 'photo_print',
          'formatId': '10x15',
          'spreadsCount': 1,
          'photosCount': 9,
        },
      );
      expectError(response, 422, ApiErrorCode.validationFailed);
      expect(fieldErrors(response)['photosCount'], 'too_many');
    });
  });

  group('delivery and pickup', () {
    test(
      'serves the six documented options with prices and thresholds',
      () async {
        final response = await api.call('GET', '/v1/delivery/options');
        expect(response.status, 200);
        final options = <DeliveryOption>[
          for (final raw in response.list)
            DeliveryOption.fromJson((raw! as Map).cast<String, Object?>()),
        ];
        final byId = <String, DeliveryOption>{
          for (final option in options) option.id: option,
        };
        expect(byId['pickup_main']!.price.amountMinor, 0);
        expect(byId['europochta']!.price.amountMinor, 590);
        expect(byId['belpochta']!.price.amountMinor, 690);
        expect(byId['ems']!.price.amountMinor, 2090);
        expect(byId['courier_minsk']!.price.amountMinor, 1490);
        expect(byId['courier_belarus']!.price.amountMinor, 1990);
        expect(byId['europochta']!.freeFrom!.amountMinor, 15000);
        expect(byId['ems']!.freeFrom!.amountMinor, 30000);
        expect(byId['pickup_main']!.requiresPoint, isTrue);
      },
    );

    test('serves the point and a deterministic 7-day slot grid', () async {
      final response = await api.call('GET', '/v1/pickup/points');
      expect(response.status, 200, reason: response.text);
      final point = PickupPoint.fromJson(
        (response.list.single! as Map).cast<String, Object?>(),
      );
      expect(point.address, 'Минский проспект, 32, корпус В3');
      expect(point.city, 'Минск');
      expect(point.slots, isNotEmpty);
      for (var i = 1; i < point.slots.length; i++) {
        expect(point.slots[i].start.isAfter(point.slots[i - 1].start), isTrue);
      }
      expect(point.slots.first.start.isUtc, isTrue);
      expect(point.slots.every((slot) => slot.end.isAfter(slot.start)), isTrue);

      final again = await api.call('GET', '/v1/pickup/points');
      expect(again.text, response.text);
    });
  });
}
