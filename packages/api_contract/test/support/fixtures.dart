import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

T roundTrip<T>(Map<String, Object?> json, T Function(JsonMap) parse) {
  final raw = (jsonDecode(jsonEncode(json)) as Map).cast<String, Object?>();
  final result = decodeJson(raw, parse);
  expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
  return result.requireValue;
}

String shaFor(String seed) {
  var value = 7;
  for (final unit in seed.codeUnits) {
    value = (value * 31 + unit) & 0xFFFFFF;
  }
  return value.toRadixString(16).padLeft(6, '0').padRight(64, 'a');
}

PhotoAsset photoAsset(String id, {int widthPx = 3000, int heightPx = 2000}) =>
    PhotoAsset(
      id: id,
      sha256: shaFor(id),
      widthPx: widthPx,
      heightPx: heightPx,
      mimeType: 'image/jpeg',
      bytes: 1024 * 1024,
    );

DesignDocument designDocument() {
  final asset = photoAsset('p0');
  return DesignDocument(
    product: const DocumentProduct(id: 'photo_print', formatId: '10x15'),
    spreads: <Spread>[
      Spread(
        id: 's0',
        templateId: 'single_10x15',
        background: SpreadBackground.color('#FFFFFF'),
        slots: <Slot>[Slot(id: 'main', photoId: asset.id)],
      ),
    ],
    spreadsCount: 1,
    assets: <PhotoAsset>[asset],
  );
}

ProductFormat productFormat() => ProductFormat(
  id: '10x15',
  productId: 'photo_print',
  title: '10×15',
  widthMm: 100,
  heightMm: 150,
  etaDays: 3,
  minPhotos: 1,
  maxPhotos: 1,
  templates: const <ProductTemplate>[
    ProductTemplate(
      id: 'single_10x15',
      nameKey: 'template.single_10x15',
      kind: TemplateKind.print,
      aspect: 2 / 3,
      slots: <TemplateSlot>[
        TemplateSlot(id: 'main', rect: NormalizedRect.unit),
      ],
    ),
  ],
  options: const <ProductOption>[
    ProductOption(
      id: 'paper',
      title: 'Бумага',
      values: <OptionValue>[
        OptionValue(id: 'gloss', title: 'Глянец', isDefault: true),
        OptionValue(id: 'matte', title: 'Мат', priceDeltaMinor: 50),
      ],
    ),
  ],
);

CatalogResponse catalogResponse() => CatalogResponse(
  products: <Product>[
    Product(
      id: 'photo_print',
      title: 'Фотопечать',
      category: 'prints',
      currency: 'BYN',
      minPrice: const Money(amountMinor: 130, currency: 'BYN'),
      formats: <ProductFormat>[productFormat()],
    ),
  ],
  currency: 'BYN',
  updatedAt: DateTime.utc(2026, 11, 11, 9),
  region: 'BY',
);

PriceQuote priceQuote() => PriceQuote(
  total: const Money(amountMinor: 1300, currency: 'BYN'),
  breakdown: <PriceBreakdownLine>[
    const PriceBreakdownLine(
      code: 'product',
      labelKey: 'price.product',
      amount: Money(amountMinor: 1300, currency: 'BYN'),
    ),
    const PriceBreakdownLine(
      code: 'promo',
      labelKey: 'price.promo',
      amount: Money(amountMinor: 0, currency: 'BYN'),
    ),
  ],
  etaDays: 3,
  canOrder: true,
  deliveryMinor: 0,
  productionMinor: 1300,
);

Map<String, Object?> orderJson({
  String paymentStatus = 'succeeded',
  String fulfillmentStatus = 'production',
}) => <String, Object?>{
  'id': 'o1',
  'number': 'PP-1001',
  'createdAt': '2026-11-11T09:00:00+03:00',
  'updatedAt': '2026-11-11T10:30:00Z',
  'items': <Object?>[
    <String, Object?>{
      'designId': 'd1',
      'productId': 'photo_print',
      'productTitle': 'Фотопечать 10×15',
      'formatId': '10x15',
      'quantity': 10,
      'unitPrice': <String, Object?>{'amountMinor': 130, 'currency': 'BYN'},
      'total': <String, Object?>{'amountMinor': 1300, 'currency': 'BYN'},
    },
  ],
  'totals': <String, Object?>{
    'subtotal': <String, Object?>{'amountMinor': 1300, 'currency': 'BYN'},
    'discount': <String, Object?>{'amountMinor': -130, 'currency': 'BYN'},
    'delivery': <String, Object?>{'amountMinor': 0, 'currency': 'BYN'},
    'total': <String, Object?>{'amountMinor': 1170, 'currency': 'BYN'},
    'promoCode': 'TEST10',
  },
  'delivery': <String, Object?>{
    'kind': 'pickup',
    'optionId': 'pickup_main',
    'pointId': 'main',
    'slot': '2026-11-14T10:00:00+03:00',
    'pickupCode': '4821',
  },
  'paymentStatus': paymentStatus,
  'fulfillmentStatus': fulfillmentStatus,
  'history': <Object?>[
    <String, Object?>{
      'status': 'accepted',
      'at': '2026-11-11T09:05:00Z',
      'commentKey': 'order.comment.accepted',
    },
  ],
  'eta': '2026-11-14T00:00:00Z',
  'contactPhoneLast4': '1234',
};

Order order({
  String paymentStatus = 'succeeded',
  String fulfillmentStatus = 'production',
}) => Order.fromJson(
  orderJson(paymentStatus: paymentStatus, fulfillmentStatus: fulfillmentStatus),
);
