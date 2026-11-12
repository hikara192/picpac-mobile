import 'package:api_contract/api_contract.dart';

const int maxCartQuantity = 100;

enum PricingUnit {
  sheet,

  spread;

  bool get isSheet => this == PricingUnit.sheet;
}

PricingUnit pricingUnitOf(ProductFormat format) =>
    format.minSpreads <= 0 ? PricingUnit.sheet : PricingUnit.spread;

int sheetCountOf(DesignDocument document) {
  final materialised = document.spreads.length;
  if (materialised > 0) return materialised;
  return document.spreadsCount < 1 ? 1 : document.spreadsCount;
}

int cartQuantityFor({
  required ProductFormat format,
  required DesignDocument document,
  int copies = 1,
}) {
  if (pricingUnitOf(format).isSheet) {
    return clampQuantity(sheetCountOf(document));
  }
  return clampQuantity(copies);
}

int pricingUnits({
  required ProductFormat format,
  required int quantity,
  required int documentSpreads,
}) {
  if (pricingUnitOf(format).isSheet) return quantity < 1 ? 1 : quantity;
  final spreads = documentSpreads < format.minSpreads
      ? format.minSpreads
      : documentSpreads;
  return spreads < 1 ? format.minSpreads : spreads;
}

int clampQuantity(int value) {
  if (value < 1) return 1;
  if (value > maxCartQuantity) return maxCartQuantity;
  return value;
}
