import 'package:design_core/design_core.dart';

import '../json.dart';
import '../money.dart';

final class OptionValue with ValueJson {
  const OptionValue({
    required this.id,
    required this.title,
    this.priceDeltaMinor = 0,
    this.currency,
    this.isDefault = false,
    this.pricingRuleId,
  });

  final String id;

  final String title;

  final int priceDeltaMinor;

  final String? currency;

  final bool isDefault;

  final String? pricingRuleId;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'priceDeltaMinor': priceDeltaMinor,
    if (currency != null) 'currency': currency,
    'isDefault': isDefault,
    if (pricingRuleId != null) 'pricingRuleId': pricingRuleId,
  };

  factory OptionValue.fromJson(
    JsonMap json, [
    String path = r'$',
  ]) => OptionValue(
    id: J.readId(json['id'], '$path.id'),
    title: J.readString(json['title'], '$path.title'),
    priceDeltaMinor:
        J.readIntOrNull(json['priceDeltaMinor'], '$path.priceDeltaMinor') ?? 0,
    currency: J.readIdOrNull(json['currency'], '$path.currency'),
    isDefault: J.readBoolOr(
      json['isDefault'],
      '$path.isDefault',
      fallback: false,
    ),
    pricingRuleId: J.readIdOrNull(json['pricingRuleId'], '$path.pricingRuleId'),
  );
}

final class ProductOption with ValueJson {
  const ProductOption({
    required this.id,
    required this.title,
    required this.values,
    this.isRequired = true,
    this.isMultiple = false,
  });

  final String id;

  final String title;

  final bool isRequired;

  final bool isMultiple;

  final List<OptionValue> values;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'isRequired': isRequired,
    'isMultiple': isMultiple,
    'values': <Object?>[for (final value in values) value.toJson()],
  };

  factory ProductOption.fromJson(JsonMap json, [String path = r'$']) {
    final valuesJson = J.readList(json['values'], '$path.values');
    return ProductOption(
      id: J.readId(json['id'], '$path.id'),
      title: J.readString(json['title'], '$path.title'),
      isRequired: J.readBoolOr(
        json['isRequired'],
        '$path.isRequired',
        fallback: true,
      ),
      isMultiple: J.readBoolOr(
        json['isMultiple'],
        '$path.isMultiple',
        fallback: false,
      ),
      values: List<OptionValue>.unmodifiable(<OptionValue>[
        for (var i = 0; i < valuesJson.length; i++)
          OptionValue.fromJson(
            J.readObject(valuesJson[i], '$path.values[$i]'),
            '$path.values[$i]',
          ),
      ]),
    );
  }
}

final class ProductTemplate with ValueJson {
  const ProductTemplate({
    required this.id,
    required this.nameKey,
    required this.kind,
    required this.slots,
    this.aspect = 1,
  });

  final String id;

  final String nameKey;

  final TemplateKind kind;

  final List<TemplateSlot> slots;

  final double aspect;

  PrintTemplate toPrintTemplate() => PrintTemplate(
    id: id,
    nameKey: nameKey,
    kind: kind,
    slots: slots,
    aspect: aspect,
  );

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'nameKey': nameKey,
    'kind': kind.wire,
    'aspect': aspect,
    'slots': <Object?>[for (final slot in slots) slot.toJson()],
  };

  factory ProductTemplate.fromJson(JsonMap json, [String path = r'$']) {
    final slots = J.readList(json['slots'], '$path.slots');
    return ProductTemplate(
      id: J.readId(json['id'], '$path.id'),
      nameKey: J.readId(json['nameKey'], '$path.nameKey'),
      kind: J.readEnum<TemplateKind>(
        json['kind'],
        '$path.kind',
        values: TemplateKind.values,
        wire: (kind) => kind.wire,
        fallback: TemplateKind.other,
      ),
      aspect: J.readDoubleOrNull(json['aspect'], '$path.aspect') ?? 1,
      slots: List<TemplateSlot>.unmodifiable(<TemplateSlot>[
        for (var i = 0; i < slots.length; i++)
          TemplateSlot.fromJson(slots[i], '$path.slots[$i]'),
      ]),
    );
  }
}

final class ProductFormat with ValueJson {
  const ProductFormat({
    required this.id,
    required this.productId,
    required this.title,
    required this.widthMm,
    required this.heightMm,
    this.bleedMm = 0,
    this.safeMm = 0,
    this.dpi = PrintSpec.defaultDpi,
    this.minPhotos = 0,
    this.maxPhotos = 0,
    this.minSpreads = 0,
    this.maxSpreads = 0,
    this.spreadStep = 0,
    this.spreadWidthMm,
    this.spreadHeightMm,
    this.coverWidthMm,
    this.coverHeightMm,
    this.etaDays = 0,
    this.templates = const <ProductTemplate>[],
    this.options = const <ProductOption>[],
  });

  final String id;

  final String productId;

  final String title;

  final double widthMm;

  final double heightMm;

  final double bleedMm;

  final double safeMm;

  final int dpi;

  final int minPhotos;

  final int maxPhotos;

  final int minSpreads;

  final int maxSpreads;

  final int spreadStep;

  final double? spreadWidthMm;

  final double? spreadHeightMm;

  final double? coverWidthMm;

  final double? coverHeightMm;

  final int etaDays;

  final List<ProductTemplate> templates;

  final List<ProductOption> options;

  PrintSpec toPrintSpec() => PrintSpec(
    widthMm: widthMm,
    heightMm: heightMm,
    bleedMm: bleedMm,
    safeMm: safeMm,
    dpi: dpi,
    spreadWidthMm: spreadWidthMm,
    spreadHeightMm: spreadHeightMm,
    coverWidthMm: coverWidthMm,
    coverHeightMm: coverHeightMm,
  );

  FormatSpec toFormatSpec() => FormatSpec(
    id: id,
    print: toPrintSpec(),
    minPhotos: minPhotos,
    maxPhotos: maxPhotos,
    minSpreads: minSpreads,
    maxSpreads: maxSpreads,
    spreadStep: spreadStep,
  );

  Map<String, PrintTemplate> templateMap() => <String, PrintTemplate>{
    for (final template in templates) template.id: template.toPrintTemplate(),
  };

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'productId': productId,
    'title': title,
    'widthMm': widthMm,
    'heightMm': heightMm,
    'bleedMm': bleedMm,
    'safeMm': safeMm,
    'dpi': dpi,
    'minPhotos': minPhotos,
    'maxPhotos': maxPhotos,
    'minSpreads': minSpreads,
    'maxSpreads': maxSpreads,
    'spreadStep': spreadStep,
    if (spreadWidthMm != null) 'spreadWidthMm': spreadWidthMm,
    if (spreadHeightMm != null) 'spreadHeightMm': spreadHeightMm,
    if (coverWidthMm != null) 'coverWidthMm': coverWidthMm,
    if (coverHeightMm != null) 'coverHeightMm': coverHeightMm,
    'etaDays': etaDays,
    'templates': <Object?>[for (final template in templates) template.toJson()],
    'options': <Object?>[for (final option in options) option.toJson()],
  };

  factory ProductFormat.fromJson(JsonMap json, [String path = r'$']) {
    final templatesJson = json['templates'] == null
        ? const <Object?>[]
        : J.readList(json['templates'], '$path.templates');
    final optionsJson = json['options'] == null
        ? const <Object?>[]
        : J.readList(json['options'], '$path.options');
    return ProductFormat(
      id: J.readId(json['id'], '$path.id'),
      productId: J.readId(json['productId'], '$path.productId'),
      title: J.readString(json['title'], '$path.title'),
      widthMm: J.readDouble(json['widthMm'], '$path.widthMm'),
      heightMm: J.readDouble(json['heightMm'], '$path.heightMm'),
      bleedMm: J.readDoubleOrNull(json['bleedMm'], '$path.bleedMm') ?? 0,
      safeMm: J.readDoubleOrNull(json['safeMm'], '$path.safeMm') ?? 0,
      dpi: J.readIntOrNull(json['dpi'], '$path.dpi') ?? PrintSpec.defaultDpi,
      minPhotos: J.readIntOrNull(json['minPhotos'], '$path.minPhotos') ?? 0,
      maxPhotos: J.readIntOrNull(json['maxPhotos'], '$path.maxPhotos') ?? 0,
      minSpreads: J.readIntOrNull(json['minSpreads'], '$path.minSpreads') ?? 0,
      maxSpreads: J.readIntOrNull(json['maxSpreads'], '$path.maxSpreads') ?? 0,
      spreadStep: J.readIntOrNull(json['spreadStep'], '$path.spreadStep') ?? 0,
      spreadWidthMm: J.readDoubleOrNull(
        json['spreadWidthMm'],
        '$path.spreadWidthMm',
      ),
      spreadHeightMm: J.readDoubleOrNull(
        json['spreadHeightMm'],
        '$path.spreadHeightMm',
      ),
      coverWidthMm: J.readDoubleOrNull(
        json['coverWidthMm'],
        '$path.coverWidthMm',
      ),
      coverHeightMm: J.readDoubleOrNull(
        json['coverHeightMm'],
        '$path.coverHeightMm',
      ),
      etaDays: J.readIntOrNull(json['etaDays'], '$path.etaDays') ?? 0,
      templates: <ProductTemplate>[
        for (var i = 0; i < templatesJson.length; i++)
          ProductTemplate.fromJson(
            J.readObject(templatesJson[i], '$path.templates[$i]'),
            '$path.templates[$i]',
          ),
      ],
      options: <ProductOption>[
        for (var i = 0; i < optionsJson.length; i++)
          ProductOption.fromJson(
            J.readObject(optionsJson[i], '$path.options[$i]'),
            '$path.options[$i]',
          ),
      ],
    );
  }
}

final class Product with ValueJson {
  const Product({
    required this.id,
    required this.title,
    required this.category,
    required this.currency,
    this.formats = const <ProductFormat>[],
    this.options = const <ProductOption>[],
    this.minPrice,
    this.imageUrl,
    this.isActive = true,
  });

  final String id;

  final String title;

  final String category;

  final String currency;

  final List<ProductFormat> formats;

  final List<ProductOption> options;

  final Money? minPrice;

  final String? imageUrl;

  final bool isActive;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'category': category,
    'currency': currency,
    if (minPrice != null) 'minPrice': minPrice!.toJson(),
    if (imageUrl != null) 'imageUrl': imageUrl,
    'isActive': isActive,
    'formats': <Object?>[for (final format in formats) format.toJson()],
    'options': <Object?>[for (final option in options) option.toJson()],
  };

  factory Product.fromJson(JsonMap json, [String path = r'$']) {
    final formats = J.readList(
      json['formats'] ?? const <Object?>[],
      '$path.formats',
    );
    final options = J.readList(
      json['options'] ?? const <Object?>[],
      '$path.options',
    );
    final minPrice = json['minPrice'];
    return Product(
      id: J.readId(json['id'], '$path.id'),
      title: J.readString(json['title'], '$path.title'),
      category: J.readId(json['category'], '$path.category'),
      currency: J.readId(json['currency'], '$path.currency').toUpperCase(),
      formats: <ProductFormat>[
        for (var i = 0; i < formats.length; i++)
          ProductFormat.fromJson(
            J.readObject(formats[i], '$path.formats[$i]'),
            '$path.formats[$i]',
          ),
      ],
      options: <ProductOption>[
        for (var i = 0; i < options.length; i++)
          ProductOption.fromJson(
            J.readObject(options[i], '$path.options[$i]'),
            '$path.options[$i]',
          ),
      ],
      minPrice: minPrice == null
          ? null
          : Money.fromJson(minPrice, '$path.minPrice'),
      imageUrl: J.readStringOrNull(json['imageUrl'], '$path.imageUrl'),
      isActive: J.readBoolOr(
        json['isActive'],
        '$path.isActive',
        fallback: true,
      ),
    );
  }
}

final class CatalogResponse with ValueJson {
  const CatalogResponse({
    required this.products,
    required this.currency,
    required this.updatedAt,
    this.region,
  });

  final List<Product> products;

  final String currency;

  final DateTime updatedAt;

  final String? region;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'products': <Object?>[for (final product in products) product.toJson()],
    'currency': currency,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (region != null) 'region': region,
  };

  factory CatalogResponse.fromJson(JsonMap json, [String path = r'$']) {
    final products = J.readList(json['products'], '$path.products');
    return CatalogResponse(
      products: <Product>[
        for (var i = 0; i < products.length; i++)
          Product.fromJson(
            J.readObject(products[i], '$path.products[$i]'),
            '$path.products[$i]',
          ),
      ],
      currency: J.readId(json['currency'], '$path.currency').toUpperCase(),
      updatedAt: J.readDate(json['updatedAt'], '$path.updatedAt'),
      region: J.readIdOrNull(json['region'], '$path.region'),
    );
  }
}
