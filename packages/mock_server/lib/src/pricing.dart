import 'package:api_contract/api_contract.dart';

import 'errors.dart';
import 'seeds.dart';

final class PriceLine {
  const PriceLine(this.code, this.labelKey, this.amountMinor);

  final String code;

  final String labelKey;

  final int amountMinor;

  PriceBreakdownLine toDto(String currency) => PriceBreakdownLine(
    code: code,
    labelKey: labelKey,
    amount: Money(amountMinor: amountMinor, currency: currency),
  );
}

final class Quote {
  const Quote({
    required this.currency,
    required this.unitPriceMinor,
    required this.productMinor,
    required this.optionsMinor,
    required this.itemsSubtotalMinor,
    required this.discountMinor,
    required this.deliveryMinor,
    required this.totalMinor,
    required this.etaDays,
    required this.lines,
    this.promoCode,
    this.canOrder = true,
  });

  final String currency;

  final int unitPriceMinor;

  final int productMinor;

  final int optionsMinor;

  final int itemsSubtotalMinor;

  final int discountMinor;

  final int deliveryMinor;

  final int totalMinor;

  final int etaDays;

  final List<PriceLine> lines;

  final String? promoCode;

  final bool canOrder;

  int get productionMinor => itemsSubtotalMinor + discountMinor;

  PriceQuote toDto() => PriceQuote(
    total: Money(amountMinor: totalMinor, currency: currency),
    breakdown: <PriceBreakdownLine>[
      for (final line in lines) line.toDto(currency),
    ],
    etaDays: etaDays,
    canOrder: canOrder,
    deliveryMinor: deliveryMinor,
    productionMinor: productionMinor,
    promoApplied: promoCode,
  );
}

final class Pricing {
  const Pricing(this.seeds);

  final Seeds seeds;

  Quote quoteRequest(PriceRequest request) {
    final product =
        seeds.catalog.productById(request.productId) ??
        (throw ApiException.validation(
          'unknown product',
          fieldErrors: <String, String>{'productId': 'unknown_product'},
        ));
    final format =
        product.formatById(request.formatId) ??
        (throw ApiException.validation(
          'unknown format',
          fieldErrors: <String, String>{'formatId': 'unknown_format'},
        ));

    final delivery = request.delivery == null
        ? null
        : _resolveDelivery(request.delivery!);

    return quote(
      product: product,
      format: format,
      options: request.options,
      units: request.spreadsCount,
      photosCount: request.photosCount,
      promoCode: request.promoCode,
      delivery: delivery,
    );
  }

  Quote quote({
    required SeedProduct product,
    required SeedFormat format,
    Map<String, String> options = const <String, String>{},
    required int units,
    int copies = 1,
    int? photosCount,
    String? promoCode,
    SeedDeliveryOption? delivery,
  }) {
    final fieldErrors = <String, String>{};

    if (copies < 1) {
      throw ApiException.validation(
        'copies must be at least 1',
        fieldErrors: const <String, String>{'quantity': 'below_minimum'},
      );
    }

    if (!format.allowsUnits(units)) {
      fieldErrors['spreadsCount'] = units < 1
          ? 'below_minimum'
          : (format.spreadStep > 1 &&
                    format.minSpreads > 0 &&
                    (units - format.minSpreads) % format.spreadStep != 0
                ? 'invalid_step'
                : 'out_of_range');
    }

    final optionDelta = _resolveOptions(format, options, fieldErrors);

    if (photosCount != null) {
      final minPhotos = product.isPrints
          ? format.minPhotos * units
          : format.minPhotos;
      final maxPhotos = format.maxPhotos == 0
          ? null
          : product.isPrints
          ? format.maxPhotos * units
          : format.maxPhotos;
      if (photosCount < 1 || photosCount < minPhotos) {
        fieldErrors['photosCount'] = 'below_minimum';
      } else if (maxPhotos != null && photosCount > maxPhotos) {
        fieldErrors['photosCount'] = 'too_many';
      }
    }

    if (fieldErrors.isNotEmpty) {
      throw ApiException.validation(
        'the configuration is not orderable',
        fieldErrors: fieldErrors,
      );
    }

    final int productMinor;
    final int optionsMinor;
    final int unitPriceMinor;
    if (product.isPrints) {
      unitPriceMinor = format.pricing.unitPriceMinor + optionDelta;
      productMinor = format.pricing.unitPriceMinor * units * copies;
      optionsMinor = optionDelta * units * copies;
    } else {
      final base = format.priceForUnits(units);
      productMinor = base * copies;
      optionsMinor = optionDelta * copies;
      unitPriceMinor = base + optionDelta;
    }
    if (unitPriceMinor < 0) {
      throw ApiException.validation(
        'options make the unit price negative',
        fieldErrors: <String, String>{'options': 'price_below_zero'},
      );
    }

    final itemsSubtotal = productMinor + optionsMinor;
    final deliveryMinor = delivery?.priceFor(itemsSubtotal) ?? 0;

    var discount = 0;
    String? appliedPromo;
    if (promoCode != null && promoCode.trim().isNotEmpty) {
      final promotion = seeds.promotions.byCode(promoCode);
      if (promotion == null) {
        throw ApiException(
          422,
          'promo_unknown',
          'the promo code is unknown or expired',
          fieldErrors: <String, String>{'promoCode': 'promo_unknown'},
        );
      }
      appliedPromo = promotion.code;
      discount = promotion.percent >= 100
          ? -(itemsSubtotal + deliveryMinor)
          : -((itemsSubtotal * promotion.percent) ~/ 100);
    }

    final total = (itemsSubtotal + discount + deliveryMinor).clamp(0, 1 << 62);
    final lines = <PriceLine>[
      PriceLine('product', 'price.product', productMinor),
      if (optionsMinor != 0)
        PriceLine('options', 'price.options', optionsMinor),
      if (discount != 0) PriceLine('promo', 'price.promo', discount),
      if (delivery != null)
        PriceLine('delivery', 'price.delivery', deliveryMinor),
    ];

    return Quote(
      currency: seeds.catalog.currency,
      unitPriceMinor: unitPriceMinor,
      productMinor: productMinor,
      optionsMinor: optionsMinor,
      itemsSubtotalMinor: itemsSubtotal,
      discountMinor: discount,
      deliveryMinor: deliveryMinor,
      totalMinor: total,
      etaDays: product.productionDays + (delivery?.etaDays ?? 0),
      lines: lines,
      promoCode: appliedPromo,
      canOrder: total >= 0,
    );
  }

  SeedDeliveryOption resolveDeliverySelection(DeliverySelection selection) =>
      _resolveDelivery(selection);

  SeedDeliveryOption _resolveDelivery(DeliverySelection selection) {
    final id = selection.optionId;
    if (id == null || id.trim().isEmpty) {
      throw ApiException.validation(
        'delivery option is required',
        fieldErrors: <String, String>{'delivery.optionId': 'required'},
      );
    }
    final option = seeds.delivery.optionById(id);
    if (option == null) {
      throw ApiException.validation(
        'unknown delivery option',
        fieldErrors: <String, String>{'delivery.optionId': 'unknown_option'},
      );
    }
    if (option.kind != selection.kind) {
      throw ApiException.validation(
        'delivery kind does not match the option',
        fieldErrors: <String, String>{'delivery.kind': 'kind_mismatch'},
      );
    }
    if (option.requiresPoint) {
      final pointId = selection.pointId;
      if (pointId == null || seeds.delivery.pointById(pointId) == null) {
        throw ApiException.validation(
          'pickup point is required for this option',
          fieldErrors: <String, String>{'delivery.pointId': 'unknown_point'},
        );
      }
    } else {
      final address = selection.address;
      if (address == null || address.trim().length < 5) {
        throw ApiException.validation(
          'a delivery address is required for this option',
          fieldErrors: <String, String>{'delivery.address': 'required'},
        );
      }
    }
    return option;
  }

  int _resolveOptions(
    SeedFormat format,
    Map<String, String> requested,
    Map<String, String> fieldErrors,
  ) {
    var delta = 0;
    final known = <String>{for (final option in format.options) option.id};
    for (final key in requested.keys) {
      if (!known.contains(key)) {
        fieldErrors['options.$key'] = 'unknown_option';
      }
    }
    for (final option in format.options) {
      final explicit = requested[option.id];
      String? valueId = explicit;
      if (valueId == null) {
        for (final value in option.values) {
          if (value.isDefault) {
            valueId = value.id;
            break;
          }
        }
        valueId ??= option.values.isEmpty ? null : option.values.first.id;
      }
      if (valueId == null) continue;
      OptionValue? value;
      for (final candidate in option.values) {
        if (candidate.id == valueId) {
          value = candidate;
          break;
        }
      }
      if (value == null) {
        fieldErrors['options.${option.id}'] = 'unknown_value';
        continue;
      }
      delta += value.priceDeltaMinor;
    }
    return delta;
  }
}
