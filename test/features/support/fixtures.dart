import 'package:api_contract/api_contract.dart';

Money byn(int minor) => Money(amountMinor: minor, currency: 'BYN');

final DateTime testNow = DateTime.utc(2026, 11, 11, 12);

ProductFormat printFormat() => const ProductFormat(
  id: '10x15',
  productId: 'photo_print',
  title: '10×15',
  widthMm: 102,
  heightMm: 152,
  dpi: 300,
  minPhotos: 1,
  maxPhotos: 4,
  etaDays: 2,
);

ProductFormat bookFormat() => const ProductFormat(
  id: '20x20',
  productId: 'photo_book_classic',
  title: '20×20',
  widthMm: 200,
  heightMm: 203,
  spreadWidthMm: 400,
  spreadHeightMm: 203,
  minPhotos: 20,
  maxPhotos: 200,
  minSpreads: 10,
  maxSpreads: 30,
  spreadStep: 1,
  etaDays: 3,
);

Product printProduct({Money? minPrice}) => Product(
  id: 'photo_print',
  title: 'Печать фотографий',
  category: 'prints',
  currency: 'BYN',
  formats: <ProductFormat>[printFormat()],
  minPrice: minPrice ?? byn(130),
);

Product bookProduct({Money? minPrice}) => Product(
  id: 'photo_book_classic',
  title: 'Фотокнига Classic',
  category: 'books',
  currency: 'BYN',
  formats: <ProductFormat>[bookFormat()],
  minPrice: minPrice ?? byn(8100),
);

CatalogResponse catalogResponse({
  List<Product>? products,
  String currency = 'BYN',
}) => CatalogResponse(
  products: products ?? <Product>[printProduct(), bookProduct()],
  currency: currency,
  updatedAt: DateTime.utc(2026, 11, 9),
  region: 'BY',
);

PriceQuote priceQuote({
  int total = 2600,
  int etaDays = 2,
  int delivery = 0,
  int? production,
  String? promoApplied,
  bool canOrder = true,
}) {
  final productionMinor = production ?? total - delivery;
  return PriceQuote(
    total: byn(total),
    breakdown: <PriceBreakdownLine>[
      PriceBreakdownLine(
        code: 'product',
        labelKey: 'price.product',
        amount: byn(
          promoApplied == null ? productionMinor : productionMinor - 260,
        ),
      ),
      if (promoApplied != null)
        PriceBreakdownLine(
          code: 'promo',
          labelKey: 'price.promo',
          amount: byn(-260),
        ),
      if (delivery != 0)
        PriceBreakdownLine(
          code: 'delivery',
          labelKey: 'price.delivery',
          amount: byn(delivery),
        ),
    ],
    etaDays: etaDays,
    canOrder: canOrder,
    deliveryMinor: delivery,
    productionMinor: productionMinor,
    promoApplied: promoApplied,
  );
}

Cart cartFixture({
  int quantity = 2,
  int subtotal = 2600,
  String? promoCode,
  bool canCheckout = true,
  DateTime? expiresAt,
}) => Cart(
  id: 'cart_1',
  items: <CartItem>[
    CartItem(
      id: 'cli_1',
      designId: 'dsg_1',
      quantity: quantity,
      quote: priceQuote(
        total: quantity * 1300,
        promoApplied: promoCode,
        production: quantity * 1300,
      ),
    ),
  ],
  expiresAt: expiresAt ?? DateTime.utc(2026, 11, 25),
  subtotal: byn(subtotal),
  promoCode: promoCode,
  canCheckout: canCheckout,
);

DeliveryOption deliveryOption({
  String id = 'pickup_main',
  DeliveryKind kind = DeliveryKind.pickup,
  String titleKey = 'delivery.pickup',
  int price = 0,
  int etaDays = 0,
  bool requiresPoint = true,
  int? freeFrom,
}) => DeliveryOption(
  id: id,
  kind: kind,
  titleKey: titleKey,
  price: byn(price),
  freeFrom: freeFrom == null ? null : byn(freeFrom),
  etaDays: etaDays,
  requiresPoint: requiresPoint,
);

PickupPoint pickupPoint() => PickupPoint(
  id: 'main',
  title: 'PicPac на Минском',
  address: 'Минский проспект, 32',
  city: 'Минск',
  slots: <PickupSlot>[
    PickupSlot(
      start: DateTime.utc(2026, 11, 12, 7),
      end: DateTime.utc(2026, 11, 12, 9),
    ),
    PickupSlot(
      start: DateTime.utc(2026, 11, 12, 10),
      end: DateTime.utc(2026, 11, 12, 12),
    ),
  ],
);

Order orderFixture({
  String id = 'ord_1',
  String number = 'PP-1001',
  PaymentStatus paymentStatus = PaymentStatus.created,
  OrderStatus fulfillmentStatus = OrderStatus.placed,
  List<OrderStatusEvent>? history,
  String? pickupCode = '1001',
  DateTime? eta,
  int totalMinor = 2600,
}) => Order(
  id: id,
  number: number,
  createdAt: DateTime.utc(2026, 11, 11, 9),
  updatedAt: DateTime.utc(2026, 11, 11, 9),
  items: <OrderItem>[
    OrderItem(
      designId: 'dsg_1',
      productId: 'photo_print',
      productTitle: 'Печать фотографий 10×15',
      formatId: '10x15',
      quantity: 2,
      unitPrice: byn(1300),
      total: byn(totalMinor),
    ),
  ],
  totals: OrderTotals(
    subtotal: byn(totalMinor),
    discount: byn(0),
    delivery: byn(0),
    total: byn(totalMinor),
  ),
  delivery: OrderDelivery(
    kind: DeliveryKind.pickup,
    optionId: 'pickup_main',
    pointId: 'main',
    slot: DateTime.utc(2026, 11, 12, 7),
    pickupCode: pickupCode,
  ),
  paymentStatus: paymentStatus,
  fulfillmentStatus: fulfillmentStatus,
  history:
      history ??
      <OrderStatusEvent>[
        OrderStatusEvent(
          status: OrderStatus.placed,
          at: DateTime.utc(2026, 11, 11, 9),
        ),
      ],
  eta: eta ?? DateTime.utc(2026, 11, 14),
  contactPhoneLast4: '1234',
);

DesignDto designFixture({String id = 'dsg_1'}) => DesignDto(
  id: id,
  revision: 1,
  document: DesignDocument.start(
    product: const DocumentProduct(id: 'photo_print', formatId: '10x15'),
  ),
  updatedAt: testNow,
);

DesignDocument documentedDesign() => DesignDocument(
  revision: 1,
  product: const DocumentProduct(id: 'photo_print', formatId: '10x15'),
  spreads: <Spread>[
    Spread(
      id: 'spread_1',
      templateId: 'single_10x15',
      background: SpreadBackground.color('#FAF5ED'),
      slots: const <Slot>[Slot(id: 'main', photoId: 'photo_1')],
    ),
  ],
  spreadsCount: 1,
  assets: <PhotoAsset>[
    PhotoAsset(
      id: 'photo_1',
      sha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      widthPx: 1600,
      heightPx: 2400,
      mimeType: 'image/jpeg',
      bytes: 220000,
    ),
  ],
);

SupportTicket supportTicketFixture({
  String id = 'tkt_1',
  String subject = 'Проблема с заказом',
  TicketType type = TicketType.defect,
  TicketStatus status = TicketStatus.open,
  String? orderId,
  List<TicketMessage>? messages,
  DateTime? updatedAt,
}) => SupportTicket(
  id: id,
  subject: subject,
  type: type,
  status: status,
  createdAt: testNow,
  updatedAt: updatedAt ?? testNow,
  orderId: orderId,
  messages:
      messages ??
      <TicketMessage>[
        TicketMessage(
          id: 'msg_1',
          authorRole: UserRole.customer,
          body: 'Здравствуйте, фото пришли с полосой.',
          createdAt: testNow,
        ),
      ],
);

TicketMessage ticketMessageFixture({
  String id = 'msg_1',
  UserRole author = UserRole.customer,
  String body = 'Здравствуйте',
  DateTime? createdAt,
}) => TicketMessage(
  id: id,
  authorRole: author,
  body: body,
  createdAt: createdAt ?? testNow,
);

DesignDto bookDesignFixture({String id = 'dsg_book'}) => DesignDto(
  id: id,
  revision: 1,
  document: DesignDocument(
    revision: 1,
    product: const DocumentProduct(id: 'photo_book_classic', formatId: '20x20'),
    spreads: <Spread>[
      for (var index = 0; index < 10; index++)
        Spread(
          id: 'sheet_${index + 1}',
          templateId: 'spread_20x20',
          background: SpreadBackground.color('#FAF5ED'),
          slots: const <Slot>[Slot(id: 'left', photoId: 'photo_left')],
        ),
    ],
    spreadsCount: 10,
  ),
  updatedAt: testNow,
);

Cart bookCartFixture({
  int quantity = 1,
  int subtotal = 8100,
  String? promoCode,
  bool canCheckout = true,
}) => Cart(
  id: 'cart_book',
  items: <CartItem>[
    CartItem(
      id: 'cli_book',
      designId: 'dsg_book',
      quantity: quantity,
      quote: priceQuote(
        total: quantity * 8100,
        production: quantity * 8100,
        etaDays: 3,
      ),
    ),
  ],
  expiresAt: DateTime.utc(2026, 11, 25),
  subtotal: byn(subtotal),
  promoCode: promoCode,
  canCheckout: canCheckout,
);

DesignDto printDesignFixture({
  int sheets = 2,
  String id = 'dsg_1',
}) => DesignDto(
  id: id,
  revision: 1,
  document: DesignDocument(
    revision: 1,
    product: const DocumentProduct(id: 'photo_print', formatId: '10x15'),
    spreads: <Spread>[
      for (var index = 0; index < sheets; index++)
        Spread(
          id: 'sheet_${index + 1}',
          templateId: 'single_10x15',
          background: SpreadBackground.color('#FAF5ED'),
          slots: const <Slot>[Slot(id: 'main', photoId: 'photo_1')],
        ),
    ],
    spreadsCount: sheets,
    assets: <PhotoAsset>[
      PhotoAsset(
        id: 'photo_1',
        sha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        widthPx: 1600,
        heightPx: 2400,
        mimeType: 'image/jpeg',
        bytes: 220000,
      ),
    ],
  ),
  updatedAt: testNow,
);
