import '../json.dart';
import '../money.dart';
import 'delivery.dart';

final class PriceBreakdownLine with ValueJson {
  const PriceBreakdownLine({
    required this.code,
    required this.labelKey,
    required this.amount,
  });

  final String code;

  final String labelKey;

  final Money amount;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'labelKey': labelKey,
    'amount': amount.toJson(),
  };

  factory PriceBreakdownLine.fromJson(JsonMap json, [String path = r'$']) =>
      PriceBreakdownLine(
        code: J.readId(json['code'], '$path.code'),
        labelKey: J.readId(json['labelKey'], '$path.labelKey'),
        amount: J.readMoney(json['amount'], '$path.amount'),
      );
}

final class PriceQuote with ValueJson {
  const PriceQuote({
    required this.total,
    this.breakdown = const <PriceBreakdownLine>[],
    this.etaDays = 0,
    this.canOrder = true,
    this.deliveryMinor = 0,
    this.productionMinor = 0,
    this.promoApplied,
  });

  final Money total;

  final List<PriceBreakdownLine> breakdown;

  final int etaDays;

  final bool canOrder;

  final int deliveryMinor;

  final int productionMinor;

  final String? promoApplied;

  String get currency => total.currency;

  Money get delivery => Money(amountMinor: deliveryMinor, currency: currency);

  Money get production =>
      Money(amountMinor: productionMinor, currency: currency);

  bool get isFree => total.isZero;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'total': total.toJson(),
    'breakdown': <Object?>[for (final line in breakdown) line.toJson()],
    'etaDays': etaDays,
    'canOrder': canOrder,
    'deliveryMinor': deliveryMinor,
    'productionMinor': productionMinor,
    if (promoApplied != null) 'promoApplied': promoApplied,
  };

  factory PriceQuote.fromJson(JsonMap json, [String path = r'$']) {
    final linesJson = json['breakdown'] == null
        ? const <Object?>[]
        : J.readList(json['breakdown'], '$path.breakdown');
    return PriceQuote(
      total: Money.nonNegativeFromJson(json['total'], '$path.total'),
      breakdown: <PriceBreakdownLine>[
        for (var i = 0; i < linesJson.length; i++)
          PriceBreakdownLine.fromJson(
            J.readObject(linesJson[i], '$path.breakdown[$i]'),
            '$path.breakdown[$i]',
          ),
      ],
      etaDays: J.readIntOrNull(json['etaDays'], '$path.etaDays') ?? 0,
      canOrder: J.readBoolOr(
        json['canOrder'],
        '$path.canOrder',
        fallback: true,
      ),
      deliveryMinor:
          J.readIntOrNull(json['deliveryMinor'], '$path.deliveryMinor') ?? 0,
      productionMinor:
          J.readIntOrNull(json['productionMinor'], '$path.productionMinor') ??
          0,
      promoApplied: J.readIdOrNull(json['promoApplied'], '$path.promoApplied'),
    );
  }
}

final class PriceRequest with ValueJson {
  const PriceRequest({
    required this.productId,
    required this.formatId,
    this.options = const <String, String>{},
    this.spreadsCount = 1,
    this.photosCount,
    this.designId,
    this.promoCode,
    this.delivery,
  });

  final String productId;

  final String formatId;

  final Map<String, String> options;

  final int spreadsCount;

  final int? photosCount;

  final String? designId;

  final String? promoCode;

  final DeliverySelection? delivery;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'productId': productId,
    'formatId': formatId,
    'options': options,
    'spreadsCount': spreadsCount,
    if (photosCount != null) 'photosCount': photosCount,
    if (designId != null) 'designId': designId,
    if (promoCode != null) 'promoCode': promoCode,
    if (delivery != null) 'delivery': delivery!.toJson(),
  };

  factory PriceRequest.fromJson(JsonMap json, [String path = r'$']) =>
      PriceRequest(
        productId: J.readId(json['productId'], '$path.productId'),
        formatId: J.readId(json['formatId'], '$path.formatId'),
        options: json['options'] == null
            ? const <String, String>{}
            : J.readStringMap(json['options'], '$path.options'),
        spreadsCount:
            J.readIntOrNull(json['spreadsCount'], '$path.spreadsCount') ?? 1,
        photosCount: J.readIntOrNull(json['photosCount'], '$path.photosCount'),
        designId: J.readIdOrNull(json['designId'], '$path.designId'),
        promoCode: J.readIdOrNull(json['promoCode'], '$path.promoCode'),
        delivery: json['delivery'] == null
            ? null
            : DeliverySelection.fromJson(
                J.readObject(json['delivery'], '$path.delivery'),
                '$path.delivery',
              ),
      );
}
