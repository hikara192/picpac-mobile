import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  group('catalog', () {
    test('round-trips the catalogue with formats, options and templates', () {
      final catalog = catalogResponse();
      final decoded = roundTrip(catalog.toJson(), CatalogResponse.fromJson);
      expect(decoded, catalog);
      expect(decoded.currency, 'BYN');
      expect(decoded.updatedAt.isUtc, isTrue);
      final product = decoded.products.single;
      expect(product.formats.single.options.single.values.length, 2);
      expect(product.minPrice!.amountMinor, 130);
    });

    test('converts a format into design_core print and format specs', () {
      final format = productFormat();
      final printSpec = format.toPrintSpec();
      expect(printSpec.widthMm, 100);
      expect(printSpec.heightMm, 150);
      expect(printSpec.dpi, PrintSpec.defaultDpi);
      expect(printSpec.targetPxWidth, 1181);
      expect(printSpec.targetPxHeight, 1772);

      final formatSpec = format.toFormatSpec();
      expect(formatSpec.id, '10x15');
      expect(formatSpec.minPhotos, 1);
      expect(formatSpec.maxPhotos, 1);
    });

    test('templates become PrintTemplate values for preflight', () {
      final templates = productFormat().templateMap();
      expect(templates.keys, contains('single_10x15'));
      final template = templates['single_10x15']!;
      expect(template.slots.single.rect, NormalizedRect.unit);
      expect(template.kind, TemplateKind.print);
    });

    test('unknown template kind falls back to other', () {
      final json = productFormat().toJson();
      final templates = json['templates']! as List<Object?>;
      (templates.single! as Map<String, Object?>)['kind'] = 'hologram';
      final decoded = roundTrip(json, (map) => ProductFormat.fromJson(map));
      expect(decoded.templates.single.kind, TemplateKind.other);
    });

    test('missing format size is invalid_response with a path', () {
      final json = productFormat().toJson()..remove('widthMm');
      final result = decodeJson(json, ProductFormat.fromJson);
      expect(result.failureOrNull!.code, ApiErrorCode.invalidResponse);
      expect(result.failureOrNull!.args['path'], r'$.widthMm');
    });
  });

  group('pricing', () {
    test('round-trips a quote with a negative breakdown line', () {
      final quote = priceQuote();
      final decoded = roundTrip(quote.toJson(), PriceQuote.fromJson);
      expect(decoded, quote);
      expect(decoded.currency, 'BYN');
      expect(decoded.production.amountMinor, 1300);
      expect(decoded.delivery.isZero, isTrue);
      expect(decoded.isFree, isFalse);

      final withDiscount = PriceQuote(
        total: const Money(amountMinor: 1170, currency: 'BYN'),
        breakdown: <PriceBreakdownLine>[
          const PriceBreakdownLine(
            code: 'promo',
            labelKey: 'price.promo',
            amount: Money(amountMinor: -130, currency: 'BYN'),
          ),
        ],
        promoApplied: 'TEST10',
      );
      final decodedDiscount = roundTrip(
        withDiscount.toJson(),
        PriceQuote.fromJson,
      );
      expect(decodedDiscount.breakdown.single.amount.isRefund, isTrue);
      expect(decodedDiscount.promoApplied, 'TEST10');
    });

    test('a decimal total is rejected as invalid_money', () {
      final json = priceQuote().toJson();
      json['total'] = <String, Object?>{
        'amountMinor': 12.34,
        'currency': 'BYN',
      };
      final result = decodeJson(json, PriceQuote.fromJson);
      expect(result.failureOrNull!.code, ApiErrorCode.invalidMoney);
      expect(result.failureOrNull!.args['path'], r'$.total.amountMinor');
    });

    test('a 100 % promo produces a free quote', () {
      final quote = PriceQuote(
        total: const Money(amountMinor: 0, currency: 'BYN'),
        promoApplied: 'FREE100',
      );
      expect(quote.isFree, isTrue);
    });

    test('round-trips a price request with delivery selection', () {
      const request = PriceRequest(
        productId: 'photo_print',
        formatId: '10x15',
        options: <String, String>{'paper': 'gloss'},
        spreadsCount: 10,
        photosCount: 10,
        promoCode: 'TEST10',
        delivery: DeliverySelection(
          kind: DeliveryKind.pickup,
          optionId: 'pickup_main',
          pointId: 'main',
        ),
      );
      final decoded = roundTrip(request.toJson(), PriceRequest.fromJson);
      expect(decoded, request);
      expect(decoded.delivery!.kind, DeliveryKind.pickup);
    });
  });

  group('delivery', () {
    test('round-trips options and pickup points with slots', () {
      const option = DeliveryOption(
        id: 'europochta',
        kind: DeliveryKind.post,
        titleKey: 'delivery.europochta',
        price: Money(amountMinor: 590, currency: 'BYN'),
        freeFrom: Money(amountMinor: 15000, currency: 'BYN'),
        etaDays: 3,
        requiresPoint: true,
      );
      expect(roundTrip(option.toJson(), DeliveryOption.fromJson), option);

      final point = PickupPoint(
        id: 'main',
        title: 'PicPac',
        address: 'Минский проспект, 32, корпус В3',
        city: 'Минск',
        lat: 53.9,
        lng: 27.5,
        slots: <PickupSlot>[
          PickupSlot(
            start: DateTime.utc(2026, 11, 14, 7),
            end: DateTime.utc(2026, 11, 14, 8),
          ),
        ],
      );
      final decoded = roundTrip(point.toJson(), PickupPoint.fromJson);
      expect(decoded, point);
      expect(decoded.slots.single.available, isTrue);
      expect(decoded.slots.single.start.isUtc, isTrue);
    });

    test('round-trips a courier selection with local offset normalised', () {
      const selection = DeliverySelection(
        kind: DeliveryKind.courier,
        optionId: 'courier_minsk',
        address: 'ул. Примерная, 1',
      );
      final decoded = roundTrip(selection.toJson(), DeliverySelection.fromJson);
      expect(decoded, selection);
    });
  });
}
