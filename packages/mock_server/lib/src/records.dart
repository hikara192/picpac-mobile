import 'package:api_contract/api_contract.dart';


final class CustomerRecord {
  CustomerRecord({
    required this.id,
    required this.createdAt,
    required this.role,
    required this.isGuest,
    this.name,
    this.email,
    this.phoneMasked,
    this.deleted = false,
  });

  final String id;

  final DateTime createdAt;

  final UserRole role;

  final bool isGuest;

  final String? name;

  final String? email;

  final String? phoneMasked;

  bool deleted;

  Customer toDto() => Customer(
    id: id,
    createdAt: createdAt,
    name: name,
    email: email,
    phoneMasked: phoneMasked,
    isGuest: isGuest,
  );
}

final class SessionRecord {
  SessionRecord({
    required this.id,
    required this.customerId,
    required this.role,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;

  final String customerId;

  final UserRole role;

  final DateTime createdAt;

  final DateTime expiresAt;

  bool revoked = false;

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now);
}

final class UploadRecord {
  UploadRecord({
    required this.id,
    required this.ownerId,
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    required this.sha256,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;

  final String ownerId;

  final String fileName;

  final String mimeType;

  final int bytes;

  final String sha256;

  final DateTime createdAt;

  final DateTime expiresAt;

  int? receivedBytes;

  String? receivedSha256;

  bool uploaded = false;

  bool completed = false;

  int widthPx = 0;

  int heightPx = 0;

  CompletedUpload toDto() => CompletedUpload(
    uploadId: id,
    sha256: sha256,
    widthPx: widthPx,
    heightPx: heightPx,
    mimeType: mimeType,
    bytes: receivedBytes ?? bytes,
  );
}

final class DesignRecord {
  DesignRecord({
    required this.id,
    required this.ownerId,
    required this.revision,
    required this.document,
    required this.createdAt,
    required this.updatedAt,
    this.title,
  });

  final String id;

  final String ownerId;

  int revision;

  DesignDocument document;

  final DateTime createdAt;

  DateTime updatedAt;

  final String? title;

  DesignDto toDto() => DesignDto(
    id: id,
    revision: revision,
    document: document,
    updatedAt: updatedAt,
    createdAt: createdAt,
    title: title,
  );
}

final class CartLineRecord {
  CartLineRecord({
    required this.id,
    required this.designId,
    required this.quantity,
  });

  final String id;

  final String designId;

  int quantity;
}

final class CartRecord {
  CartRecord({
    required this.id,
    required this.customerId,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;

  final String customerId;

  final DateTime createdAt;

  DateTime expiresAt;

  String? promoCode;

  final List<CartLineRecord> lines = <CartLineRecord>[];

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now);
}

final class OrderLineRecord {
  const OrderLineRecord({
    required this.designId,
    required this.productId,
    required this.productTitle,
    required this.formatId,
    required this.quantity,
    required this.unitPriceMinor,
    required this.totalMinor,
  });

  final String designId;

  final String productId;

  final String productTitle;

  final String formatId;

  final int quantity;

  final int unitPriceMinor;

  final int totalMinor;

  OrderItem toDto(String currency) => OrderItem(
    designId: designId,
    productId: productId,
    productTitle: productTitle,
    formatId: formatId,
    quantity: quantity,
    unitPrice: Money(amountMinor: unitPriceMinor, currency: currency),
    total: Money(amountMinor: totalMinor, currency: currency),
  );
}

final class StatusEventRecord {
  const StatusEventRecord({
    required this.status,
    required this.at,
    this.commentKey,
  });

  final String status;

  final DateTime at;

  final String? commentKey;

  OrderStatusEvent toDto() => OrderStatusEvent(
    status: OrderStatus.fromWire(status),
    at: at,
    commentKey: commentKey,
  );
}

final class OrderRecord {
  OrderRecord({
    required this.id,
    required this.number,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    required this.itemsSubtotalMinor,
    required this.discountMinor,
    required this.deliveryMinor,
    required this.totalMinor,
    required this.paymentStatus,
    required this.fulfillmentStatus,
    required this.deliveryKind,
    required this.contactName,
    required this.contactPhone,
    required this.contactPhoneLast4,
    required this.currency,
    this.promoCode,
    this.deliveryOptionId,
    this.deliveryPointId,
    this.deliveryAddress,
    this.deliverySlot,
    this.eta,
    this.trackingNumber,
    this.pickupCode,
    List<StatusEventRecord>? history,
  }) : history = history ?? <StatusEventRecord>[];

  final String id;

  final String number;

  String ownerId;

  final Set<String> accessIds = <String>{};

  bool accessibleBy(String customerId) =>
      ownerId == customerId || accessIds.contains(customerId);

  final DateTime createdAt;

  DateTime updatedAt;

  final List<OrderLineRecord> items;

  final int itemsSubtotalMinor;

  final int discountMinor;

  final int deliveryMinor;

  final int totalMinor;

  final String? promoCode;

  String paymentStatus;

  String fulfillmentStatus;

  final DeliveryKind deliveryKind;

  final String? deliveryOptionId;

  final String? deliveryPointId;

  final String? deliveryAddress;

  final DateTime? deliverySlot;

  final DateTime? eta;

  String? trackingNumber;

  final String? pickupCode;

  final String contactName;

  final String contactPhone;

  final String contactPhoneLast4;

  final String currency;

  final List<StatusEventRecord> history;

  Map<String, Object?> toJson() {
    final dto = Order(
      id: id,
      number: number,
      createdAt: createdAt,
      updatedAt: updatedAt,
      items: <OrderItem>[for (final item in items) item.toDto(currency)],
      totals: OrderTotals(
        subtotal: Money(amountMinor: itemsSubtotalMinor, currency: currency),
        discount: Money(amountMinor: discountMinor, currency: currency),
        delivery: Money(amountMinor: deliveryMinor, currency: currency),
        total: Money(amountMinor: totalMinor, currency: currency),
        promoCode: promoCode,
      ),
      delivery: OrderDelivery(
        kind: deliveryKind,
        optionId: deliveryOptionId,
        pointId: deliveryPointId,
        address: deliveryAddress,
        slot: deliverySlot,
        trackingNumber: trackingNumber,
        pickupCode: pickupCode,
      ),
      paymentStatus: PaymentStatus.fromWire(paymentStatus),
      fulfillmentStatus: OrderStatus.fromWire(fulfillmentStatus),
      history: <OrderStatusEvent>[for (final event in history) event.toDto()],
      eta: eta,
      trackingNumber: trackingNumber,
      contactPhoneLast4: contactPhoneLast4,
    );
    final json = dto.toJson();
    if (OrderStatus.fromWire(fulfillmentStatus) == OrderStatus.unknown) {
      json['fulfillmentStatus'] = fulfillmentStatus;
    }
    if (PaymentStatus.fromWire(paymentStatus) == PaymentStatus.unknown) {
      json['paymentStatus'] = paymentStatus;
    }
    final historyJson = json['history'];
    if (historyJson is List) {
      for (var i = 0; i < history.length && i < historyJson.length; i++) {
        final entry = historyJson[i];
        final raw = history[i].status;
        if (entry is Map<String, Object?> &&
            OrderStatus.fromWire(raw) == OrderStatus.unknown) {
          entry['status'] = raw;
        }
      }
    }
    return json;
  }

  Map<String, Object?> toPublicCardJson() {
    final dto = Order(
      id: id,
      number: number,
      createdAt: createdAt,
      updatedAt: updatedAt,
      items: const <OrderItem>[],
      totals: OrderTotals(
        subtotal: Money(amountMinor: itemsSubtotalMinor, currency: currency),
        discount: Money(amountMinor: discountMinor, currency: currency),
        delivery: Money(amountMinor: deliveryMinor, currency: currency),
        total: Money(amountMinor: totalMinor, currency: currency),
        promoCode: promoCode,
      ),
      delivery: OrderDelivery(
        kind: deliveryKind,
        optionId: deliveryOptionId,
        pointId: deliveryPointId,
      ),
      paymentStatus: PaymentStatus.fromWire(paymentStatus),
      fulfillmentStatus: OrderStatus.fromWire(fulfillmentStatus),
    );
    final json = dto.toJson();
    if (OrderStatus.fromWire(fulfillmentStatus) == OrderStatus.unknown) {
      json['fulfillmentStatus'] = fulfillmentStatus;
    }
    if (PaymentStatus.fromWire(paymentStatus) == PaymentStatus.unknown) {
      json['paymentStatus'] = paymentStatus;
    }
    return json;
  }

  bool get isPaid => PaymentStatus.fromWire(paymentStatus).isPaid;

  String? latestIntentId;

  final List<RefundRecord> refunds = <RefundRecord>[];
}

final class IntentRecord {
  IntentRecord({
    required this.id,
    required this.orderId,
    required this.provider,
    required this.methodId,
    required this.amountMinor,
    required this.currency,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    this.hostedPageUrl,
    this.eripCode,
    this.qrPayload,
    this.failureCode,
    this.pendingWebhookAt,
  });

  final String id;

  final String orderId;

  final String provider;

  final String methodId;

  final int amountMinor;

  final String currency;

  final DateTime createdAt;

  final DateTime expiresAt;

  String status;

  String? hostedPageUrl;

  String? eripCode;

  String? qrPayload;

  String? failureCode;

  DateTime? pendingWebhookAt;

  PaymentIntent toDto() => PaymentIntent(
    id: id,
    orderId: orderId,
    status: PaymentStatus.fromWire(status),
    amount: Money(amountMinor: amountMinor, currency: currency),
    provider: provider,
    createdAt: createdAt,
    methodId: methodId,
    hostedPageUrl: hostedPageUrl,
    qrPayload: qrPayload,
    eripCode: eripCode,
    expiresAt: expiresAt,
    failureCode: failureCode,
  );

  Map<String, Object?> toJson() {
    final json = toDto().toJson();
    if (PaymentStatus.fromWire(status) == PaymentStatus.unknown) {
      json['status'] = status;
    }
    return json;
  }

  bool get isPending => PaymentStatus.fromWire(status).isPending;

  bool get isTerminal => PaymentStatus.fromWire(status).isTerminal;
}

final class RefundRecord {
  const RefundRecord({
    required this.id,
    required this.orderId,
    required this.intentId,
    required this.amountMinor,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.reasonKey,
  });

  final String id;

  final String orderId;

  final String intentId;

  final int amountMinor;

  final String currency;

  final String status;

  final DateTime createdAt;

  final String reasonKey;

  Refund toDto() => Refund(
    id: id,
    orderId: orderId,
    amount: Money(amountMinor: amountMinor, currency: currency),
    status: RefundStatus.fromWire(status),
    createdAt: createdAt,
    intentId: intentId,
    reasonKey: reasonKey,
  );
}

final class ReceiptRecord {
  const ReceiptRecord({
    required this.id,
    required this.orderId,
    required this.fiscalId,
    required this.amountMinor,
    required this.currency,
    required this.issuedAt,
    required this.url,
  });

  final String id;

  final String orderId;

  final String fiscalId;

  final int amountMinor;

  final String currency;

  final DateTime issuedAt;

  final String url;

  Receipt toDto() => Receipt(
    id: id,
    orderId: orderId,
    fiscalId: fiscalId,
    amount: Money(amountMinor: amountMinor, currency: currency),
    issuedAt: issuedAt,
    url: url,
  );
}

final class TicketMessageRecord {
  const TicketMessageRecord({
    required this.id,
    required this.authorRole,
    required this.body,
    required this.createdAt,
    this.attachments = const <String>[],
  });

  final String id;

  final UserRole authorRole;

  final String body;

  final DateTime createdAt;

  final List<String> attachments;

  TicketMessage toDto() => TicketMessage(
    id: id,
    authorRole: authorRole,
    body: body,
    createdAt: createdAt,
    attachments: attachments,
  );
}

final class TicketRecord {
  TicketRecord({
    required this.id,
    required this.ownerId,
    required this.subject,
    required this.type,
    required this.createdAt,
    this.orderId,
  }) : updatedAt = createdAt;

  final String id;

  final String ownerId;

  final String subject;

  final TicketType type;

  final String? orderId;

  final DateTime createdAt;

  DateTime updatedAt;

  TicketStatus status = TicketStatus.open;

  final List<TicketMessageRecord> messages = <TicketMessageRecord>[];

  SupportTicket toDto() => SupportTicket(
    id: id,
    subject: subject,
    type: type,
    status: status,
    createdAt: createdAt,
    updatedAt: updatedAt,
    orderId: orderId,
    messages: <TicketMessage>[for (final message in messages) message.toDto()],
  );
}

final class AuditRecordEntry {
  const AuditRecordEntry({
    required this.id,
    required this.at,
    required this.action,
    required this.objectType,
    required this.objectId,
    required this.result,
    required this.actorRole,
    this.actorId,
    this.details = const <String, Object?>{},
  });

  final String id;

  final DateTime at;

  final String action;

  final String objectType;

  final String objectId;

  final String result;

  final ActorRole actorRole;

  final String? actorId;

  final Map<String, Object?> details;

  AuditRecord toDto() => AuditRecord(
    id: id,
    at: at,
    action: action,
    objectType: objectType,
    objectId: objectId,
    result: result,
    actorRole: actorRole,
    actorId: actorId,
    details: details,
  );
}

final class IdempotencyRecord {
  const IdempotencyRecord({
    required this.key,
    required this.endpoint,
    required this.bodyHash,
    required this.customerId,
    required this.resultType,
    required this.resultId,
  });

  final String key;

  final String endpoint;

  final String bodyHash;

  final String customerId;

  final String resultType;

  final String resultId;
}
