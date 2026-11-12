import 'dart:convert';
import 'dart:io';

import 'package:api_contract/api_contract.dart';

import 'seeds.g.dart';

final class Seeds {
  Seeds({
    required this.catalog,
    required this.delivery,
    required this.payments,
    required this.promotions,
    required this.accounts,
    required this.inspiration,
  });

  factory Seeds.embedded() => Seeds.fromFiles(embeddedSeedFiles);

  static Map<String, String> get embeddedFiles =>
      Map<String, String>.unmodifiable(embeddedSeedFiles);

  factory Seeds.fromFiles(Map<String, String> files) {
    final bundle = <String, Object?>{};
    for (final entry in files.entries) {
      final decoded = jsonDecode(entry.value);
      if (decoded is! Map<String, Object?>) {
        throw StateError('seed file "${entry.key}" must be a JSON object');
      }
      final name = entry.key.endsWith('.json')
          ? entry.key.substring(0, entry.key.length - 5)
          : entry.key;
      bundle[name] = decoded;
    }
    return Seeds.fromBundle(bundle);
  }

  factory Seeds.fromBundle(Map<String, Object?> bundle) {
    final catalog = SeedCatalog.fromJson(_obj(bundle['catalog'], 'catalog'));
    final inspiration = SeedInspiration.fromJson(
      _obj(bundle['inspiration'], 'inspiration'),
    )..attachTo(catalog);
    return Seeds(
      catalog: catalog,
      delivery: SeedDelivery.fromJson(_obj(bundle['delivery'], 'delivery')),
      payments: SeedPayments.fromJson(_obj(bundle['payments'], 'payments')),
      promotions: SeedPromotions.fromJson(
        _obj(bundle['promotions'], 'promotions'),
      ),
      accounts: SeedAccounts.fromJson(_obj(bundle['accounts'], 'accounts')),
      inspiration: inspiration,
    );
  }

  static Seeds load({String? seedPath}) {
    final explicit = seedPath ?? Platform.environment['PICPAK_MOCK_SEED_PATH'];
    if (explicit != null && explicit.isNotEmpty) {
      final resolved = _readPath(explicit);
      if (resolved != null) return resolved;
      throw StateError('seed path "$explicit" does not exist');
    }
    for (final candidate in _candidatePaths()) {
      final resolved = _readPath(candidate);
      if (resolved != null) return resolved;
    }
    return Seeds.embedded();
  }

  final SeedCatalog catalog;

  final SeedDelivery delivery;

  final SeedPayments payments;

  final SeedPromotions promotions;

  final SeedAccounts accounts;

  final SeedInspiration inspiration;

  String get seededAt => catalog.seededAt;

  static Seeds? _readPath(String path) {
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.directory) {
      final files = <String, String>{};
      for (final name in const <String>[
        'accounts.json',
        'catalog.json',
        'delivery.json',
        'inspiration.json',
        'payments.json',
        'promotions.json',
      ]) {
        final file = File('$path/$name');
        if (!file.existsSync()) {
          throw StateError('seed file "${file.path}" is missing');
        }
        files[name] = file.readAsStringSync();
      }
      return Seeds.fromFiles(files);
    }
    if (type == FileSystemEntityType.file) {
      final decoded = jsonDecode(File(path).readAsStringSync());
      if (decoded is! Map<String, Object?>) {
        throw StateError('seed file "$path" must contain a JSON object');
      }
      if (decoded.containsKey('catalog')) return Seeds.fromBundle(decoded);
      final name = path.split(Platform.pathSeparator).last;
      return Seeds.fromFiles(<String, String>{name: jsonEncode(decoded)});
    }
    return null;
  }

  static Iterable<String> _candidatePaths() sync* {
    yield 'seeds';
    yield 'packages/mock_server/seeds';
    yield '../seeds';
    final script = Platform.script;
    if (script.isScheme('file')) {
      final directory = File(script.toFilePath()).parent;
      yield '${directory.path}/../seeds';
    }
  }
}

final class SeedCatalog {
  SeedCatalog({
    required this.seededAt,
    required this.source,
    required this.currency,
    required this.region,
    required this.products,
  });

  factory SeedCatalog.fromJson(Map<String, Object?> json) {
    final products = _list(json['products'], 'catalog.products');
    return SeedCatalog(
      seededAt: _str(json['seededAt'], 'catalog.seededAt'),
      source: _str(json['source'], 'catalog.source'),
      currency: _str(json['currency'], 'catalog.currency').toUpperCase(),
      region: _str(json['region'], 'catalog.region'),
      products: <SeedProduct>[
        for (var i = 0; i < products.length; i++)
          SeedProduct.fromJson(_obj(products[i], 'catalog.products[$i]')),
      ],
    );
  }

  final String seededAt;

  final String source;

  final String currency;

  final String region;

  final List<SeedProduct> products;

  DateTime get updatedAt => DateTime.parse('${seededAt}T00:00:00Z');

  SeedProduct? productById(String id) {
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  CatalogResponse toDto() => CatalogResponse(
    products: <Product>[
      for (final product in products) product.toDto(currency),
    ],
    currency: currency,
    updatedAt: updatedAt,
    region: region,
  );
}

final class SeedProduct {
  const SeedProduct({
    required this.id,
    required this.title,
    required this.category,
    required this.kind,
    required this.productionDays,
    required this.formats,
  });

  factory SeedProduct.fromJson(Map<String, Object?> json) {
    final formats = _list(json['formats'], 'product.formats');
    return SeedProduct(
      id: _str(json['id'], 'product.id'),
      title: _str(json['title'], 'product.title'),
      category: _str(json['category'], 'product.category'),
      kind: _str(json['kind'], 'product.kind'),
      productionDays: _int(json['productionDays'], 'product.productionDays'),
      formats: <SeedFormat>[
        for (var i = 0; i < formats.length; i++)
          SeedFormat.fromJson(
            _obj(formats[i], 'product.formats[$i]'),
            'product.formats[$i]',
          ),
      ],
    );
  }

  final String id;

  final String title;

  final String category;

  final String kind;

  final int productionDays;

  final List<SeedFormat> formats;

  SeedFormat? formatById(String formatId) {
    for (final format in formats) {
      if (format.id == formatId) return format;
    }
    return null;
  }

  bool get isPrints => kind == 'prints';

  Product toDto(String currency) => Product(
    id: id,
    title: title,
    category: category,
    currency: currency,
    formats: <ProductFormat>[for (final f in formats) f.toDto(this)],
    minPrice: formats.isEmpty
        ? null
        : Money(
            amountMinor: formats
                .map(_basePrice)
                .reduce((a, b) => a < b ? a : b),
            currency: currency,
          ),
    isActive: true,
  );

  int _basePrice(SeedFormat format) => switch (format.pricing.kind) {
    SeedPricingKind.perUnit => format.pricing.unitPriceMinor,
    SeedPricingKind.perSpread => format.pricing.baseMinor,
  };
}

enum SeedPricingKind {
  perUnit,

  perSpread,
}

final class SeedPricing {
  const SeedPricing({
    required this.kind,
    this.unitPriceMinor = 0,
    this.baseMinor = 0,
    this.incrementMinor = 0,
  });

  factory SeedPricing.fromJson(Map<String, Object?> json) {
    final kind = _str(json['kind'], 'pricing.kind');
    return SeedPricing(
      kind: switch (kind) {
        'perUnit' => SeedPricingKind.perUnit,
        'perSpread' => SeedPricingKind.perSpread,
        _ => throw StateError('unknown pricing kind "$kind"'),
      },
      unitPriceMinor: _intOr(
        json['unitPriceMinor'],
        0,
        'pricing.unitPriceMinor',
      ),
      baseMinor: _intOr(json['baseMinor'], 0, 'pricing.baseMinor'),
      incrementMinor: _intOr(
        json['incrementMinor'],
        0,
        'pricing.incrementMinor',
      ),
    );
  }

  final SeedPricingKind kind;

  final int unitPriceMinor;

  final int baseMinor;

  final int incrementMinor;
}

final class SeedFormat {
  const SeedFormat({
    required this.id,
    required this.title,
    required this.widthMm,
    required this.heightMm,
    required this.bleedMm,
    required this.safeMm,
    required this.dpi,
    required this.minPhotos,
    required this.maxPhotos,
    required this.minSpreads,
    required this.maxSpreads,
    required this.spreadStep,
    required this.pricing,
    required this.options,
    required this.templates,
    this.spreadWidthMm,
    this.spreadHeightMm,
    this.coverWidthMm,
    this.coverHeightMm,
  });

  factory SeedFormat.fromJson(Map<String, Object?> json, String path) {
    final options = _listOrEmpty(json['options'], '$path.options');
    final templates = _listOrEmpty(json['templates'], '$path.templates');
    return SeedFormat(
      id: _str(json['id'], '$path.id'),
      title: _str(json['title'], '$path.title'),
      widthMm: _double(json['widthMm'], '$path.widthMm'),
      heightMm: _double(json['heightMm'], '$path.heightMm'),
      bleedMm: _doubleOr(json['bleedMm'], 0, '$path.bleedMm'),
      safeMm: _doubleOr(json['safeMm'], 0, '$path.safeMm'),
      dpi: _intOr(json['dpi'], 300, '$path.dpi'),
      minPhotos: _intOr(json['minPhotos'], 0, '$path.minPhotos'),
      maxPhotos: _intOr(json['maxPhotos'], 0, '$path.maxPhotos'),
      minSpreads: _intOr(json['minSpreads'], 0, '$path.minSpreads'),
      maxSpreads: _intOr(json['maxSpreads'], 0, '$path.maxSpreads'),
      spreadStep: _intOr(json['spreadStep'], 0, '$path.spreadStep'),
      pricing: SeedPricing.fromJson(_obj(json['pricing'], '$path.pricing')),
      options: <ProductOption>[
        for (var i = 0; i < options.length; i++)
          ProductOption.fromJson(
            _obj(options[i], '$path.options[$i]'),
            '$path.options[$i]',
          ),
      ],
      templates: <ProductTemplate>[
        for (var i = 0; i < templates.length; i++)
          ProductTemplate.fromJson(
            _obj(templates[i], '$path.templates[$i]'),
            '$path.templates[$i]',
          ),
      ],
      spreadWidthMm: _doubleOrNull(
        json['spreadWidthMm'],
        '$path.spreadWidthMm',
      ),
      spreadHeightMm: _doubleOrNull(
        json['spreadHeightMm'],
        '$path.spreadHeightMm',
      ),
      coverWidthMm: _doubleOrNull(json['coverWidthMm'], '$path.coverWidthMm'),
      coverHeightMm: _doubleOrNull(
        json['coverHeightMm'],
        '$path.coverHeightMm',
      ),
    );
  }

  final String id;

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

  final SeedPricing pricing;

  final List<ProductOption> options;

  final List<ProductTemplate> templates;

  final double? spreadWidthMm;

  final double? spreadHeightMm;

  final double? coverWidthMm;

  final double? coverHeightMm;

  ProductFormat toDto(SeedProduct product) => ProductFormat(
    id: id,
    productId: product.id,
    title: title,
    widthMm: widthMm,
    heightMm: heightMm,
    bleedMm: bleedMm,
    safeMm: safeMm,
    dpi: dpi,
    minPhotos: minPhotos,
    maxPhotos: maxPhotos,
    minSpreads: minSpreads,
    maxSpreads: maxSpreads,
    spreadStep: spreadStep,
    spreadWidthMm: spreadWidthMm,
    spreadHeightMm: spreadHeightMm,
    coverWidthMm: coverWidthMm,
    coverHeightMm: coverHeightMm,
    etaDays: product.productionDays,
    templates: templates,
    options: options,
  );

  int priceForUnits(int units) => switch (pricing.kind) {
    SeedPricingKind.perUnit => pricing.unitPriceMinor * units,
    SeedPricingKind.perSpread =>
      pricing.baseMinor +
          ((units - minSpreads) ~/ _step) * pricing.incrementMinor,
  };

  int get _step => spreadStep < 1 ? 1 : spreadStep;

  bool allowsUnits(int units) {
    if (units < 1) return false;
    if (pricing.kind == SeedPricingKind.perUnit) return true;
    if (minSpreads > 0 && units < minSpreads) return false;
    if (maxSpreads > 0 && units > maxSpreads) return false;
    if (spreadStep > 1 && (units - minSpreads) % spreadStep != 0) return false;
    return true;
  }

  Map<String, PrintTemplate> templateMap() => <String, PrintTemplate>{
    for (final template in templates) template.id: template.toPrintTemplate(),
  };
}

final class SeedDelivery {
  const SeedDelivery({
    required this.seededAt,
    required this.source,
    required this.currency,
    required this.options,
    required this.pickupPoints,
    required this.schedule,
  });

  factory SeedDelivery.fromJson(Map<String, Object?> json) {
    final options = _list(json['options'], 'delivery.options');
    final points = _list(json['pickupPoints'], 'delivery.pickupPoints');
    return SeedDelivery(
      seededAt: _str(json['seededAt'], 'delivery.seededAt'),
      source: _str(json['source'], 'delivery.source'),
      currency: _str(json['currency'], 'delivery.currency').toUpperCase(),
      options: <SeedDeliveryOption>[
        for (var i = 0; i < options.length; i++)
          SeedDeliveryOption.fromJson(_obj(options[i], 'delivery.options[$i]')),
      ],
      pickupPoints: <SeedPickupPoint>[
        for (var i = 0; i < points.length; i++)
          SeedPickupPoint.fromJson(
            _obj(points[i], 'delivery.pickupPoints[$i]'),
          ),
      ],
      schedule: SeedPickupSchedule.fromJson(
        _obj(json['pickupSchedule'], 'delivery.pickupSchedule'),
      ),
    );
  }

  final String seededAt;

  final String source;

  final String currency;

  final List<SeedDeliveryOption> options;

  final List<SeedPickupPoint> pickupPoints;

  final SeedPickupSchedule schedule;

  SeedDeliveryOption? optionById(String id) {
    for (final option in options) {
      if (option.id == id) return option;
    }
    return null;
  }

  SeedPickupPoint? pointById(String id) {
    for (final point in pickupPoints) {
      if (point.id == id) return point;
    }
    return null;
  }
}

final class SeedDeliveryOption {
  const SeedDeliveryOption({
    required this.id,
    required this.kind,
    required this.titleKey,
    required this.priceMinor,
    required this.etaDays,
    required this.requiresPoint,
    required this.allowsCashOnDelivery,
    this.freeFromMinor,
  });

  factory SeedDeliveryOption.fromJson(Map<String, Object?> json) {
    final kind = _str(json['kind'], 'delivery.kind');
    return SeedDeliveryOption(
      id: _str(json['id'], 'delivery.id'),
      kind: DeliveryKind.fromWire(kind),
      titleKey: _str(json['titleKey'], 'delivery.titleKey'),
      priceMinor: _int(json['priceMinor'], 'delivery.priceMinor'),
      freeFromMinor: _intOrNull(
        json['freeFromMinor'],
        'delivery.freeFromMinor',
      ),
      etaDays: _intOr(json['etaDays'], 0, 'delivery.etaDays'),
      requiresPoint: _boolOr(
        json['requiresPoint'],
        false,
        'delivery.requiresPoint',
      ),
      allowsCashOnDelivery: _boolOr(
        json['allowsCashOnDelivery'],
        false,
        'delivery.allowsCashOnDelivery',
      ),
    );
  }

  final String id;

  final DeliveryKind kind;

  final String titleKey;

  final int priceMinor;

  final int? freeFromMinor;

  final int etaDays;

  final bool requiresPoint;

  final bool allowsCashOnDelivery;

  int priceFor(int subtotalMinor) {
    final threshold = freeFromMinor;
    if (threshold != null && subtotalMinor >= threshold) return 0;
    return priceMinor;
  }

  DeliveryOption toDto(String currency) => DeliveryOption(
    id: id,
    kind: kind,
    titleKey: titleKey,
    price: Money(amountMinor: priceMinor, currency: currency),
    freeFrom: freeFromMinor == null
        ? null
        : Money(amountMinor: freeFromMinor!, currency: currency),
    etaDays: etaDays,
    requiresPoint: requiresPoint,
    allowsCashOnDelivery: allowsCashOnDelivery,
  );
}

final class SeedPickupPoint {
  const SeedPickupPoint({
    required this.id,
    required this.title,
    required this.address,
    required this.city,
  });

  factory SeedPickupPoint.fromJson(Map<String, Object?> json) =>
      SeedPickupPoint(
        id: _str(json['id'], 'pickupPoint.id'),
        title: _str(json['title'], 'pickupPoint.title'),
        address: _str(json['address'], 'pickupPoint.address'),
        city: _str(json['city'], 'pickupPoint.city'),
      );

  final String id;

  final String title;

  final String address;

  final String city;
}

final class SeedPickupSchedule {
  const SeedPickupSchedule({
    required this.utcOffsetHours,
    required this.daysAhead,
    required this.slotStartHoursLocal,
    required this.slotDurationHours,
    required this.closedWeekdays,
  });

  factory SeedPickupSchedule.fromJson(Map<String, Object?> json) {
    final hours = _list(
      json['slotStartHoursLocal'],
      'pickupSchedule.slotStartHoursLocal',
    );
    final closed = _listOrEmpty(
      json['closedWeekdays'],
      'pickupSchedule.closedWeekdays',
    );
    return SeedPickupSchedule(
      utcOffsetHours: _int(
        json['utcOffsetHours'],
        'pickupSchedule.utcOffsetHours',
      ),
      daysAhead: _int(json['daysAhead'], 'pickupSchedule.daysAhead'),
      slotStartHoursLocal: <int>[
        for (var i = 0; i < hours.length; i++)
          _int(hours[i], 'pickupSchedule.slotStartHoursLocal[$i]'),
      ],
      slotDurationHours: _int(
        json['slotDurationHours'],
        'pickupSchedule.slotDurationHours',
      ),
      closedWeekdays: <int>{
        for (var i = 0; i < closed.length; i++)
          _int(closed[i], 'pickupSchedule.closedWeekdays[$i]'),
      },
    );
  }

  final int utcOffsetHours;

  final int daysAhead;

  final List<int> slotStartHoursLocal;

  final int slotDurationHours;

  final Set<int> closedWeekdays;
}

final class SeedPayments {
  const SeedPayments({
    required this.seededAt,
    required this.source,
    required this.regions,
  });

  factory SeedPayments.fromJson(Map<String, Object?> json) {
    final regions = _list(json['regions'], 'payments.regions');
    return SeedPayments(
      seededAt: _str(json['seededAt'], 'payments.seededAt'),
      source: _str(json['source'], 'payments.source'),
      regions: <SeedPaymentRegion>[
        for (var i = 0; i < regions.length; i++)
          SeedPaymentRegion.fromJson(_obj(regions[i], 'payments.regions[$i]')),
      ],
    );
  }

  final String seededAt;

  final String source;

  final List<SeedPaymentRegion> regions;

  SeedPaymentRegion? regionByCode(String code) {
    final normalized = code.trim().toUpperCase();
    for (final region in regions) {
      if (region.region == normalized) return region;
    }
    return null;
  }
}

final class SeedPaymentRegion {
  const SeedPaymentRegion({
    required this.region,
    required this.currency,
    required this.provider,
    required this.methods,
  });

  factory SeedPaymentRegion.fromJson(Map<String, Object?> json) {
    final methods = _list(json['methods'], 'paymentRegion.methods');
    return SeedPaymentRegion(
      region: _str(json['region'], 'paymentRegion.region').toUpperCase(),
      currency: _str(json['currency'], 'paymentRegion.currency').toUpperCase(),
      provider: _str(json['provider'], 'paymentRegion.provider'),
      methods: <SeedPaymentMethod>[
        for (var i = 0; i < methods.length; i++)
          SeedPaymentMethod.fromJson(
            _obj(methods[i], 'paymentRegion.methods[$i]'),
          ),
      ],
    );
  }

  final String region;

  final String currency;

  final String provider;

  final List<SeedPaymentMethod> methods;

  SeedPaymentMethod? methodById(String id) {
    for (final method in methods) {
      if (method.id == id) return method;
    }
    return null;
  }
}

final class SeedPaymentMethod {
  const SeedPaymentMethod({
    required this.id,
    required this.titleKey,
    required this.kind,
    required this.requiresRedirect,
  });

  factory SeedPaymentMethod.fromJson(Map<String, Object?> json) =>
      SeedPaymentMethod(
        id: _str(json['id'], 'paymentMethod.id'),
        titleKey: _str(json['titleKey'], 'paymentMethod.titleKey'),
        kind: _str(json['kind'], 'paymentMethod.kind'),
        requiresRedirect: _boolOr(
          json['requiresRedirect'],
          true,
          'paymentMethod.requiresRedirect',
        ),
      );

  final String id;

  final String titleKey;

  final String kind;

  final bool requiresRedirect;

  PaymentMethodInfo toDto(SeedPaymentRegion region) => PaymentMethodInfo(
    id: id,
    titleKey: titleKey,
    kind: kind,
    currency: region.currency,
    region: region.region,
    requiresRedirect: requiresRedirect,
  );
}

final class SeedPromotions {
  const SeedPromotions({
    required this.seededAt,
    required this.source,
    required this.promotions,
  });

  factory SeedPromotions.fromJson(Map<String, Object?> json) {
    final promotions = _list(json['promotions'], 'promotions.promotions');
    return SeedPromotions(
      seededAt: _str(json['seededAt'], 'promotions.seededAt'),
      source: _str(json['source'], 'promotions.source'),
      promotions: <SeedPromotion>[
        for (var i = 0; i < promotions.length; i++)
          SeedPromotion.fromJson(
            _obj(promotions[i], 'promotions.promotions[$i]'),
          ),
      ],
    );
  }

  final String seededAt;

  final String source;

  final List<SeedPromotion> promotions;

  SeedPromotion? byCode(String? code) {
    if (code == null) return null;
    final normalized = code.trim().toUpperCase();
    for (final promotion in promotions) {
      if (promotion.code == normalized) return promotion;
    }
    return null;
  }
}

final class SeedPromotion {
  const SeedPromotion({
    required this.code,
    required this.percent,
    required this.titleKey,
  });

  factory SeedPromotion.fromJson(Map<String, Object?> json) {
    final kind = _str(json['kind'], 'promotion.kind');
    if (kind != 'percent') {
      throw StateError('unsupported promotion kind "$kind"');
    }
    final percent = _int(json['percent'], 'promotion.percent');
    if (percent < 1 || percent > 100) {
      throw StateError('promotion percent must be 1..100, got $percent');
    }
    return SeedPromotion(
      code: _str(json['code'], 'promotion.code').toUpperCase(),
      percent: percent,
      titleKey: _str(json['titleKey'], 'promotion.titleKey'),
    );
  }

  final String code;

  final int percent;

  final String titleKey;
}

final class SeedAccounts {
  const SeedAccounts({
    required this.seededAt,
    required this.source,
    required this.accounts,
    required this.challenges,
  });

  factory SeedAccounts.fromJson(Map<String, Object?> json) {
    final accounts = _list(json['accounts'], 'accounts.accounts');
    final challenges = _listOrEmpty(json['challenges'], 'accounts.challenges');
    return SeedAccounts(
      seededAt: _str(json['seededAt'], 'accounts.seededAt'),
      source: _str(json['source'], 'accounts.source'),
      accounts: <SeedAccount>[
        for (var i = 0; i < accounts.length; i++)
          SeedAccount.fromJson(_obj(accounts[i], 'accounts.accounts[$i]')),
      ],
      challenges: <SeedChallenge>[
        for (var i = 0; i < challenges.length; i++)
          SeedChallenge.fromJson(
            _obj(challenges[i], 'accounts.challenges[$i]'),
          ),
      ],
    );
  }

  final String seededAt;

  final String source;

  final List<SeedAccount> accounts;

  final List<SeedChallenge> challenges;

  SeedAccount? byEmail(String email) {
    final normalized = email.trim().toLowerCase();
    for (final account in accounts) {
      if (account.email.toLowerCase() == normalized) return account;
    }
    return null;
  }

  SeedAccount? byId(String id) {
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }
}

final class SeedAccount {
  const SeedAccount({
    required this.id,
    required this.email,
    required this.role,
    required this.name,
    required this.phoneMasked,
    required this.isGuest,
    required this.passwordHash,
  });

  factory SeedAccount.fromJson(Map<String, Object?> json) => SeedAccount(
    id: _str(json['id'], 'account.id'),
    email: _str(json['email'], 'account.email'),
    role: UserRole.fromWire(_str(json['role'], 'account.role')),
    name: _str(json['name'], 'account.name'),
    phoneMasked: _str(json['phoneMasked'], 'account.phoneMasked'),
    isGuest: _boolOr(json['isGuest'], false, 'account.isGuest'),
    passwordHash: _str(json['passwordHash'], 'account.passwordHash'),
  );

  final String id;

  final String email;

  final UserRole role;

  final String name;

  final String phoneMasked;

  final bool isGuest;

  final String passwordHash;
}

final class SeedChallenge {
  const SeedChallenge({
    required this.id,
    required this.accountId,
    required this.code,
    required this.ttlMinutes,
  });

  factory SeedChallenge.fromJson(Map<String, Object?> json) => SeedChallenge(
    id: _str(json['id'], 'challenge.id'),
    accountId: _str(json['accountId'], 'challenge.accountId'),
    code: _str(json['code'], 'challenge.code'),
    ttlMinutes: _int(json['ttlMinutes'], 'challenge.ttlMinutes'),
  );

  final String id;

  final String accountId;

  final String code;

  final int ttlMinutes;
}

final class SeedInspiration {
  const SeedInspiration({
    required this.seededAt,
    required this.source,
    required this.notes,
    required this.items,
  });

  factory SeedInspiration.fromJson(Map<String, Object?> json) {
    final items = _list(json['items'], 'inspiration.items');
    return SeedInspiration(
      seededAt: _str(json['seededAt'], 'inspiration.seededAt'),
      source: _str(json['source'], 'inspiration.source'),
      notes: <String>[
        for (final note in _listOrEmpty(json['notes'], 'inspiration.notes'))
          _str(note, 'inspiration.notes[]'),
      ],
      items: <SeedInspirationItem>[
        for (var i = 0; i < items.length; i++)
          SeedInspirationItem.fromJson(
            _obj(items[i], 'inspiration.items[$i]'),
            'inspiration.items[$i]',
          ),
      ],
    );
  }

  final String seededAt;

  final String source;

  final List<String> notes;

  final List<SeedInspirationItem> items;

  SeedInspirationItem? byId(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  void attachTo(SeedCatalog catalog) {
    for (final item in items) {
      final validation = TemplateValidator.validateGeometry(
        item.template.toPrintTemplate(),
      );
      if (!validation.isValid) {
        throw StateError(
          'inspiration template "${item.template.id}" is unusable: '
          '${validation.codes.map((code) => code.wire).join(', ')}',
        );
      }
      for (final support in item.supports) {
        final product = catalog.productById(support.productId);
        final format = product?.formatById(support.formatId);
        if (product == null || format == null) {
          throw StateError(
            'inspiration item "${item.id}" supports unknown format '
            '"${support.productId}/${support.formatId}"',
          );
        }
        if (format.maxPhotos > 0 &&
            item.template.slots.length > format.maxPhotos) {
          throw StateError(
            'inspiration template "${item.template.id}" has '
            '${item.template.slots.length} slots, but '
            '"${support.productId}/${support.formatId}" allows '
            '${format.maxPhotos}',
          );
        }
        final known = format.templates.any(
          (template) => template.id == item.template.id,
        );
        if (!known) format.templates.add(item.template);
      }
    }
  }
}

final class SeedInspirationItem {
  const SeedInspirationItem({
    required this.id,
    required this.template,
    required this.titleKey,
    required this.tags,
    required this.productKind,
    required this.popularity,
    required this.supports,
  });

  factory SeedInspirationItem.fromJson(Map<String, Object?> json, String path) {
    final tags = _listOrEmpty(json['tags'], '$path.tags');
    final supports = _list(json['supports'], '$path.supports');
    return SeedInspirationItem(
      id: _str(json['id'], '$path.id'),
      template: ProductTemplate.fromJson(
        _obj(json['template'], '$path.template'),
        '$path.template',
      ),
      titleKey: _str(json['titleKey'], '$path.titleKey'),
      tags: <String>[
        for (var i = 0; i < tags.length; i++) _str(tags[i], '$path.tags[$i]'),
      ],
      productKind: _str(json['productKind'], '$path.productKind'),
      popularity: _intOr(json['popularity'], 0, '$path.popularity'),
      supports: <SeedInspirationSupport>[
        for (var i = 0; i < supports.length; i++)
          SeedInspirationSupport.fromJson(
            _obj(supports[i], '$path.supports[$i]'),
            '$path.supports[$i]',
          ),
      ],
    );
  }

  final String id;

  final ProductTemplate template;

  final String titleKey;

  final List<String> tags;

  final String productKind;

  final int popularity;

  final List<SeedInspirationSupport> supports;
}

final class SeedInspirationSupport {
  const SeedInspirationSupport({
    required this.productId,
    required this.formatId,
  });

  factory SeedInspirationSupport.fromJson(
    Map<String, Object?> json,
    String path,
  ) => SeedInspirationSupport(
    productId: _str(json['productId'], '$path.productId'),
    formatId: _str(json['formatId'], '$path.formatId'),
  );

  final String productId;

  final String formatId;
}


Map<String, Object?> _obj(Object? value, String path) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return value.cast<String, Object?>();
  throw StateError('$path must be a JSON object');
}

List<Object?> _list(Object? value, String path) {
  if (value is List<Object?>) return value;
  if (value is List) return value.cast<Object?>();
  throw StateError('$path must be a JSON array');
}

List<Object?> _listOrEmpty(Object? value, String path) =>
    value == null ? const <Object?>[] : _list(value, path);

String _str(Object? value, String path) {
  if (value is String && value.trim().isNotEmpty) return value;
  throw StateError('$path must be a non-empty string');
}

int _int(Object? value, String path) {
  if (value is int) return value;
  throw StateError('$path must be an integer');
}

int _intOr(Object? value, int fallback, String path) =>
    value == null ? fallback : _int(value, path);

int? _intOrNull(Object? value, String path) =>
    value == null ? null : _int(value, path);

double _double(Object? value, String path) {
  if (value is num) return value.toDouble();
  throw StateError('$path must be a number');
}

double _doubleOr(Object? value, double fallback, String path) =>
    value == null ? fallback : _double(value, path);

double? _doubleOrNull(Object? value, String path) =>
    value == null ? null : _double(value, path);

bool _boolOr(Object? value, bool fallback, String path) {
  if (value == null) return fallback;
  if (value is bool) return value;
  throw StateError('$path must be a boolean');
}
