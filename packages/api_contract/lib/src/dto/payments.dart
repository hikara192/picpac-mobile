import '../json.dart';
import '../money.dart';

enum PaymentStatus {
  created('created'),

  requiresAction('requires_action'),

  pendingUser('pending_user'),

  processing('processing'),

  succeeded('succeeded'),

  failed('failed'),

  expired('expired'),

  canceled('canceled'),

  refunded('refunded'),

  partiallyRefunded('partially_refunded'),

  pendingOnDelivery('pending_on_delivery'),

  unknown('unknown');

  const PaymentStatus(this.wire);

  final String wire;

  static PaymentStatus fromWire(String? raw) {
    for (final status in values) {
      if (status != PaymentStatus.unknown && status.wire == raw) return status;
    }
    return PaymentStatus.unknown;
  }

  bool get isPaid =>
      this == PaymentStatus.succeeded ||
      this == PaymentStatus.refunded ||
      this == PaymentStatus.partiallyRefunded;

  bool get isPending =>
      this == PaymentStatus.created ||
      this == PaymentStatus.requiresAction ||
      this == PaymentStatus.pendingUser ||
      this == PaymentStatus.processing ||
      this == PaymentStatus.pendingOnDelivery;

  bool get isTerminal =>
      this == PaymentStatus.succeeded ||
      this == PaymentStatus.failed ||
      this == PaymentStatus.expired ||
      this == PaymentStatus.canceled ||
      this == PaymentStatus.refunded ||
      this == PaymentStatus.partiallyRefunded;
}

final class PaymentMethodInfo with ValueJson {
  const PaymentMethodInfo({
    required this.id,
    required this.titleKey,
    required this.kind,
    required this.currency,
    this.region,
    this.enabled = true,
    this.requiresRedirect = true,
    this.minAmountMinor,
    this.maxAmountMinor,
  });

  final String id;

  final String titleKey;

  final String kind;

  final String currency;

  final String? region;

  final bool enabled;

  final bool requiresRedirect;

  final int? minAmountMinor;

  final int? maxAmountMinor;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'titleKey': titleKey,
    'kind': kind,
    'currency': currency,
    if (region != null) 'region': region,
    'enabled': enabled,
    'requiresRedirect': requiresRedirect,
    if (minAmountMinor != null) 'minAmountMinor': minAmountMinor,
    if (maxAmountMinor != null) 'maxAmountMinor': maxAmountMinor,
  };

  factory PaymentMethodInfo.fromJson(JsonMap json, [String path = r'$']) =>
      PaymentMethodInfo(
        id: J.readId(json['id'], '$path.id'),
        titleKey: J.readId(json['titleKey'], '$path.titleKey'),
        kind: J.readId(json['kind'], '$path.kind'),
        currency: J.readId(json['currency'], '$path.currency').toUpperCase(),
        region: J.readIdOrNull(json['region'], '$path.region'),
        enabled: J.readBoolOr(json['enabled'], '$path.enabled', fallback: true),
        requiresRedirect: J.readBoolOr(
          json['requiresRedirect'],
          '$path.requiresRedirect',
          fallback: true,
        ),
        minAmountMinor: J.readIntOrNull(
          json['minAmountMinor'],
          '$path.minAmountMinor',
        ),
        maxAmountMinor: J.readIntOrNull(
          json['maxAmountMinor'],
          '$path.maxAmountMinor',
        ),
      );
}

final class PaymentIntent with ValueJson {
  const PaymentIntent({
    required this.id,
    required this.orderId,
    required this.status,
    required this.amount,
    required this.provider,
    required this.createdAt,
    this.methodId,
    this.hostedPageUrl,
    this.qrPayload,
    this.eripCode,
    this.expiresAt,
    this.failureCode,
  });

  final String id;

  final String orderId;

  final PaymentStatus status;

  final Money amount;

  final String provider;

  final DateTime createdAt;

  final String? methodId;

  final String? hostedPageUrl;

  final String? qrPayload;

  final String? eripCode;

  final DateTime? expiresAt;

  final String? failureCode;

  bool get requiresUserAction =>
      hostedPageUrl != null || qrPayload != null || eripCode != null;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'orderId': orderId,
    'status': status.wire,
    'amount': amount.toJson(),
    'provider': provider,
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (methodId != null) 'methodId': methodId,
    if (hostedPageUrl != null) 'hostedPageUrl': hostedPageUrl,
    if (qrPayload != null) 'qrPayload': qrPayload,
    if (eripCode != null) 'eripCode': eripCode,
    if (expiresAt != null) 'expiresAt': expiresAt!.toUtc().toIso8601String(),
    if (failureCode != null) 'failureCode': failureCode,
  };

  factory PaymentIntent.fromJson(JsonMap json, [String path = r'$']) =>
      PaymentIntent(
        id: J.readId(json['id'], '$path.id'),
        orderId: J.readId(json['orderId'], '$path.orderId'),
        status: J.readEnum<PaymentStatus>(
          json['status'],
          '$path.status',
          values: PaymentStatus.values,
          wire: (status) => status.wire,
          fallback: PaymentStatus.unknown,
        ),
        amount: Money.nonNegativeFromJson(json['amount'], '$path.amount'),
        provider: J.readId(json['provider'], '$path.provider'),
        createdAt: J.readDate(json['createdAt'], '$path.createdAt'),
        methodId: J.readIdOrNull(json['methodId'], '$path.methodId'),
        hostedPageUrl: J.readStringOrNull(
          json['hostedPageUrl'],
          '$path.hostedPageUrl',
        ),
        qrPayload: J.readStringOrNull(json['qrPayload'], '$path.qrPayload'),
        eripCode: J.readIdOrNull(json['eripCode'], '$path.eripCode'),
        expiresAt: J.readDateOrNull(json['expiresAt'], '$path.expiresAt'),
        failureCode: J.readIdOrNull(json['failureCode'], '$path.failureCode'),
      );
}

final class Receipt with ValueJson {
  const Receipt({
    required this.id,
    required this.orderId,
    required this.fiscalId,
    required this.amount,
    required this.issuedAt,
    this.url,
    this.vat,
  });

  final String id;

  final String orderId;

  final String fiscalId;

  final Money amount;

  final DateTime issuedAt;

  final String? url;

  final Money? vat;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'orderId': orderId,
    'fiscalId': fiscalId,
    'amount': amount.toJson(),
    'issuedAt': issuedAt.toUtc().toIso8601String(),
    if (url != null) 'url': url,
    if (vat != null) 'vat': vat!.toJson(),
  };

  factory Receipt.fromJson(JsonMap json, [String path = r'$']) {
    final vatJson = json['vat'];
    return Receipt(
      id: J.readId(json['id'], '$path.id'),
      orderId: J.readId(json['orderId'], '$path.orderId'),
      fiscalId: J.readId(json['fiscalId'], '$path.fiscalId'),
      amount: Money.nonNegativeFromJson(json['amount'], '$path.amount'),
      issuedAt: J.readDate(json['issuedAt'], '$path.issuedAt'),
      url: J.readStringOrNull(json['url'], '$path.url'),
      vat: vatJson == null ? null : J.readMoney(vatJson, '$path.vat'),
    );
  }
}

enum RefundStatus {
  pending('pending'),

  succeeded('succeeded'),

  failed('failed'),

  unknown('unknown');

  const RefundStatus(this.wire);

  final String wire;

  static RefundStatus fromWire(String? raw) {
    for (final status in values) {
      if (status != RefundStatus.unknown && status.wire == raw) return status;
    }
    return RefundStatus.unknown;
  }
}

final class Refund with ValueJson {
  const Refund({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.intentId,
    this.reasonKey,
  });

  final String id;

  final String orderId;

  final Money amount;

  final RefundStatus status;

  final DateTime createdAt;

  final String? intentId;

  final String? reasonKey;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'orderId': orderId,
    'amount': amount.toJson(),
    'status': status.wire,
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (intentId != null) 'intentId': intentId,
    if (reasonKey != null) 'reasonKey': reasonKey,
  };

  factory Refund.fromJson(JsonMap json, [String path = r'$']) => Refund(
    id: J.readId(json['id'], '$path.id'),
    orderId: J.readId(json['orderId'], '$path.orderId'),
    amount: Money.nonNegativeFromJson(json['amount'], '$path.amount'),
    status: J.readEnum<RefundStatus>(
      json['status'],
      '$path.status',
      values: RefundStatus.values,
      wire: (status) => status.wire,
      fallback: RefundStatus.unknown,
    ),
    createdAt: J.readDate(json['createdAt'], '$path.createdAt'),
    intentId: J.readIdOrNull(json['intentId'], '$path.intentId'),
    reasonKey: J.readIdOrNull(json['reasonKey'], '$path.reasonKey'),
  );
}

final class CreatePaymentIntentRequest with ValueJson {
  const CreatePaymentIntentRequest({
    required this.orderId,
    required this.methodId,
    this.region,
  });

  final String orderId;

  final String methodId;

  final String? region;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'orderId': orderId,
    'methodId': methodId,
    if (region != null) 'region': region,
  };

  factory CreatePaymentIntentRequest.fromJson(
    JsonMap json, [
    String path = r'$',
  ]) => CreatePaymentIntentRequest(
    orderId: J.readId(json['orderId'], '$path.orderId'),
    methodId: J.readId(json['methodId'], '$path.methodId'),
    region: J.readIdOrNull(json['region'], '$path.region'),
  );
}

final class RefundRequest with ValueJson {
  const RefundRequest({
    required this.orderId,
    required this.amountMinor,
    required this.reasonKey,
  });

  final String orderId;

  final int amountMinor;

  final String reasonKey;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'orderId': orderId,
    'amountMinor': amountMinor,
    'reasonKey': reasonKey,
  };

  factory RefundRequest.fromJson(JsonMap json, [String path = r'$']) =>
      RefundRequest(
        orderId: J.readId(json['orderId'], '$path.orderId'),
        amountMinor: J.readInt(json['amountMinor'], '$path.amountMinor'),
        reasonKey: J.readId(json['reasonKey'], '$path.reasonKey'),
      );
}
