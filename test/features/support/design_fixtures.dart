import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:crypto/crypto.dart';

ProductFormat printFormat({
  int minPhotos = 1,
  int maxPhotos = 4,
  int minSpreads = 0,
  int maxSpreads = 0,
  double widthMm = 102,
  double heightMm = 152,
  int dpi = 300,
  bool quadFirst = false,
}) => ProductFormat(
  id: '10x15',
  productId: 'photo_print',
  title: '10×15',
  widthMm: widthMm,
  heightMm: heightMm,
  dpi: dpi,
  minPhotos: minPhotos,
  maxPhotos: maxPhotos,
  minSpreads: minSpreads,
  maxSpreads: maxSpreads,
  etaDays: 2,
  templates: quadFirst
      ? <ProductTemplate>[
          _quadTemplate(widthMm / heightMm),
          _singleTemplate(widthMm / heightMm),
        ]
      : <ProductTemplate>[
          _singleTemplate(widthMm / heightMm),
          _quadTemplate(widthMm / heightMm),
        ],
);

ProductTemplate _singleTemplate(double aspect) => ProductTemplate(
  id: 'single_10x15',
  nameKey: 'template.single_10x15',
  kind: TemplateKind.print,
  aspect: aspect,
  slots: <TemplateSlot>[TemplateSlot(id: 'main', rect: NormalizedRect.unit)],
);

ProductTemplate _quadTemplate(double aspect) => ProductTemplate(
  id: 'quad_10x15',
  nameKey: 'template.quad_10x15',
  kind: TemplateKind.collage,
  aspect: aspect,
  slots: const <TemplateSlot>[
    TemplateSlot(
      id: 'tl',
      rect: NormalizedRect(x: 0, y: 0, w: 0.4975, h: 0.4975),
    ),
    TemplateSlot(
      id: 'tr',
      rect: NormalizedRect(x: 0.5025, y: 0, w: 0.4975, h: 0.4975),
    ),
    TemplateSlot(
      id: 'bl',
      rect: NormalizedRect(x: 0, y: 0.5025, w: 0.4975, h: 0.4975),
    ),
    TemplateSlot(
      id: 'br',
      rect: NormalizedRect(x: 0.5025, y: 0.5025, w: 0.4975, h: 0.4975),
    ),
  ],
);

Product printProduct(ProductFormat format) => Product(
  id: 'photo_print',
  title: 'Печать фотографий',
  category: 'prints',
  currency: 'BYN',
  formats: <ProductFormat>[format],
);

CatalogResponse catalogWith(ProductFormat format) => CatalogResponse(
  products: <Product>[printProduct(format)],
  currency: 'BYN',
  updatedAt: DateTime.utc(2026, 11, 9),
  region: 'BY',
);

DesignDto designDto({
  String id = 'dsg_1',
  int revision = 1,
  DesignDocument? document,
}) => DesignDto(
  id: id,
  revision: revision,
  document:
      document ??
      DesignDocument.start(
        product: const DocumentProduct(id: 'photo_print', formatId: '10x15'),
      ),
  updatedAt: DateTime.utc(2026, 11, 11, 12),
);

PhotoAsset photoAsset({
  required String id,
  required int widthPx,
  required int heightPx,
  String? sha256,
  String mimeType = 'image/jpeg',
  int bytes = 180000,
}) => PhotoAsset(
  id: id,
  sha256: sha256 ?? sha256Of(id),
  widthPx: widthPx,
  heightPx: heightPx,
  mimeType: mimeType,
  bytes: bytes,
);

UploadTicket uploadTicket({String uploadId = 'upl_1'}) => UploadTicket(
  uploadId: uploadId,
  url: 'http://localhost/v1/mock/uploads/$uploadId',
  headers: const <String, String>{'content-type': 'image/png'},
  expiresAt: DateTime.utc(2026, 11, 11, 12, 15),
);

CompletedUpload completedUpload({
  required String sha256,
  int widthPx = 1200,
  int heightPx = 900,
  String uploadId = 'upl_1',
}) => CompletedUpload(
  uploadId: uploadId,
  sha256: sha256,
  widthPx: widthPx,
  heightPx: heightPx,
  mimeType: 'image/png',
  bytes: 180000,
);

Cart cartWith(String designId) => Cart(
  id: 'cart_1',
  items: <CartItem>[
    CartItem(
      id: 'cli_1',
      designId: designId,
      quantity: 1,
      quote: PriceQuote(
        total: Money(amountMinor: 130, currency: 'BYN'),
        breakdown: <PriceBreakdownLine>[
          PriceBreakdownLine(
            code: 'product',
            labelKey: 'price.product',
            amount: Money(amountMinor: 130, currency: 'BYN'),
          ),
        ],
        etaDays: 2,
        canOrder: true,
        deliveryMinor: 0,
        productionMinor: 130,
      ),
    ),
  ],
  expiresAt: DateTime.utc(2026, 11, 25),
  subtotal: Money(amountMinor: 130, currency: 'BYN'),
);

PreflightDto preflightDto(
  PreflightReport report, {
  int revision = 1,
  bool canOrder = true,
}) => PreflightDto(
  revision: revision,
  canOrder: canOrder,
  issues: report.issues,
  acknowledged: report.acknowledged,
);

String sha256Of(String value) => sha256.convert(utf8.encode(value)).toString();
