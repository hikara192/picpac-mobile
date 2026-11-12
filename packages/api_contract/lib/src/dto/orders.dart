import '../json.dart';
import '../money.dart';
import 'delivery.dart';
import 'payments.dart';

enum OrderStatus {
  draft('draft'),

  placed('placed'),

  accepted('accepted'),

  moderation('moderation'),

  production('production'),

  ready('ready'),

  readyForPickup('ready_for_pickup'),

  shipped('shipped'),

  completed('completed'),

  canceled('canceled'),

  returned('returned'),

  unknown('unknown');

  const OrderStatus(this.wire);

  final String wire;

  String get messageKey => 'order.status.$wire';

  bool get isTerminal =>
      this == OrderStatus.completed ||
      this == OrderStatus.canceled ||
      this == OrderStatus.returned;

  bool get isActive => !isTerminal && this != OrderStatus.unknown;

  bool get awaitsPickup => this == OrderStatus.readyForPickup;

  static OrderStatus fromWire(String? raw) {
    for (final status in values) {
      if (status != OrderStatus.unknown && status.wire == raw) return status;
    }
    return OrderStatus.unknown;
  }
}

final class OrderItem with ValueJson {
  const OrderItem({
    required this.designId,
    required this.productId,
    required this.productTitle,
    required this.formatId,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    this.previewUrl,
  });

  final String designId;

  final String productId;

  final String productTitle;

  final String formatId;

  final int quantity;

  final Money unitPrice;

  final Money total;

  final String? previewUrl;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'designId': designId,
    'productId': productId,
    'productTitle': productTitle,
    'formatId': formatId,
    'quantity': quantity,
    'unitPrice': unitPrice.toJson(),
    'total': total.toJson(),
    if (previewUrl != null) 'previewUrl': previewUrl,
  };

  factory OrderItem.fromJson(JsonMap json, [String path = r'$']) => OrderItem(
    designId: J.readId(json['designId'], '$path.designId'),
    productId: J.readId(json['productId'], '$path.productId'),
    productTitle: J.readString(json['productTitle'], '$path.productTitle'),
    formatId: J.readId(json['formatId'], '$path.formatId'),
    quantity: J.readInt(json['quantity'], '$path.quantity'),
    unitPrice: Money.nonNegativeFromJson(json['unitPrice'], '$path.unitPrice'),
    total: Money.nonNegativeFromJson(json['total'], '$path.total'),
    previewUrl: J.readStringOrNull(json['previewUrl'], '$path.previewUrl'),
  );
}

final class OrderTotals with ValueJson {
  const OrderTotals({
    required this.subtotal,
    required this.discount,
    required this.delivery,
    required this.total,
    this.promoCode,
  });

  final Money subtotal;

  final Money discount;

  final Money delivery;

  final Money total;

  final String? promoCode;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'subtotal': subtotal.toJson(),
    'discount': discount.toJson(),
    'delivery': delivery.toJson(),
    'total': total.toJson(),
    if (promoCode != null) 'promoCode': promoCode,
  };

  factory OrderTotals.fromJson(JsonMap json, [String path = r'$']) =>
      OrderTotals(
        subtotal: Money.nonNegativeFromJson(json['subtotal'], '$path.subtotal'),
        discount: Money.fromJson(json['discount'], '$path.discount'),
        delivery: Money.nonNegativeFromJson(json['delivery'], '$path.delivery'),
        total: Money.nonNegativeFromJson(json['total'], '$path.total'),
        promoCode: J.readIdOrNull(json['promoCode'], '$path.promoCode'),
      );
}

final class OrderDelivery with ValueJson {
  const OrderDelivery({
    required this.kind,
    this.optionId,
    this.pointId,
    this.address,
    this.slot,
    this.trackingNumber,
    this.pickupCode,
  });

  final DeliveryKind kind;

  final String? optionId;

  final String? pointId;

  final String? address;

  final DateTime? slot;

  final String? trackingNumber;

  final String? pickupCode;

  bool get isPickup => kind == DeliveryKind.pickup;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.wire,
    if (optionId != null) 'optionId': optionId,
    if (pointId != null) 'pointId': pointId,
    if (address != null) 'address': address,
    if (slot != null) 'slot': slot!.toUtc().toIso8601String(),
    if (trackingNumber != null) 'trackingNumber': trackingNumber,
    if (pickupCode != null) 'pickupCode': pickupCode,
  };

  factory OrderDelivery.fromJson(JsonMap json, [String path = r'$']) =>
      OrderDelivery(
        kind: J.readEnum<DeliveryKind>(
          json['kind'],
          '$path.kind',
          values: DeliveryKind.values,
          wire: (kind) => kind.wire,
          fallback: DeliveryKind.unknown,
        ),
        optionId: J.readIdOrNull(json['optionId'], '$path.optionId'),
        pointId: J.readIdOrNull(json['pointId'], '$path.pointId'),
        address: J.readStringOrNull(json['address'], '$path.address'),
        slot: J.readDateOrNull(json['slot'], '$path.slot'),
        trackingNumber: J.readIdOrNull(
          json['trackingNumber'],
          '$path.trackingNumber',
        ),
        pickupCode: J.readIdOrNull(json['pickupCode'], '$path.pickupCode'),
      );
}

final class OrderStatusEvent with ValueJson {
  const OrderStatusEvent({
    required this.status,
    required this.at,
    this.commentKey,
  });

  final OrderStatus status;

  final DateTime at;

  final String? commentKey;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'status': status.wire,
    'at': at.toUtc().toIso8601String(),
    if (commentKey != null) 'commentKey': commentKey,
  };

  factory OrderStatusEvent.fromJson(JsonMap json, [String path = r'$']) =>
      OrderStatusEvent(
        status: J.readEnum<OrderStatus>(
          json['status'],
          '$path.status',
          values: OrderStatus.values,
          wire: (status) => status.wire,
          fallback: OrderStatus.unknown,
        ),
        at: J.readDate(json['at'], '$path.at'),
        commentKey: J.readIdOrNull(json['commentKey'], '$path.commentKey'),
      );
}

final class Order with ValueJson {
  const Order({
    required this.id,
    required this.number,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    required this.totals,
    required this.delivery,
    required this.paymentStatus,
    required this.fulfillmentStatus,
    this.history = const <OrderStatusEvent>[],
    this.eta,
    this.trackingNumber,
    this.contactPhoneLast4,
  });

  final String id;

  final String number;

  final DateTime createdAt;

  final DateTime updatedAt;

  final List<OrderItem> items;

  final OrderTotals totals;

  final OrderDelivery delivery;

  final PaymentStatus paymentStatus;

  final OrderStatus fulfillmentStatus;

  final List<OrderStatusEvent> history;

  final DateTime? eta;

  final String? trackingNumber;

  final String? contactPhoneLast4;

  bool get isPaid => paymentStatus.isPaid;

  bool get isCompleted => fulfillmentStatus.isTerminal;

  bool get hasUnknownStatus =>
      fulfillmentStatus == OrderStatus.unknown ||
      paymentStatus == PaymentStatus.unknown;

  bool get awaitsPickup => fulfillmentStatus.awaitsPickup;

  bool get isCashOnDelivery => paymentStatus == PaymentStatus.pendingOnDelivery;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'number': number,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'items': <Object?>[for (final item in items) item.toJson()],
    'totals': totals.toJson(),
    'delivery': delivery.toJson(),
    'paymentStatus': paymentStatus.wire,
    'fulfillmentStatus': fulfillmentStatus.wire,
    'history': <Object?>[for (final event in history) event.toJson()],
    if (eta != null) 'eta': eta!.toUtc().toIso8601String(),
    if (trackingNumber != null) 'trackingNumber': trackingNumber,
    if (contactPhoneLast4 != null) 'contactPhoneLast4': contactPhoneLast4,
  };

  factory Order.fromJson(JsonMap json, [String path = r'$']) {
    final itemsJson = json['items'] == null
        ? const <Object?>[]
        : J.readList(json['items'], '$path.items');
    final historyJson = json['history'] == null
        ? const <Object?>[]
        : J.readList(json['history'], '$path.history');
    return Order(
      id: J.readId(json['id'], '$path.id'),
      number: J.readId(json['number'], '$path.number'),
      createdAt: J.readDate(json['createdAt'], '$path.createdAt'),
      updatedAt: J.readDate(json['updatedAt'], '$path.updatedAt'),
      items: <OrderItem>[
        for (var i = 0; i < itemsJson.length; i++)
          OrderItem.fromJson(
            J.readObject(itemsJson[i], '$path.items[$i]'),
            '$path.items[$i]',
          ),
      ],
      totals: OrderTotals.fromJson(
        J.readObject(json['totals'], '$path.totals'),
        '$path.totals',
      ),
      delivery: OrderDelivery.fromJson(
        J.readObject(json['delivery'], '$path.delivery'),
        '$path.delivery',
      ),
      paymentStatus: J.readEnum<PaymentStatus>(
        json['paymentStatus'],
        '$path.paymentStatus',
        values: PaymentStatus.values,
        wire: (status) => status.wire,
        fallback: PaymentStatus.unknown,
      ),
      fulfillmentStatus: J.readEnum<OrderStatus>(
        json['fulfillmentStatus'],
        '$path.fulfillmentStatus',
        values: OrderStatus.values,
        wire: (status) => status.wire,
        fallback: OrderStatus.unknown,
      ),
      history: <OrderStatusEvent>[
        for (var i = 0; i < historyJson.length; i++)
          OrderStatusEvent.fromJson(
            J.readObject(historyJson[i], '$path.history[$i]'),
            '$path.history[$i]',
          ),
      ],
      eta: J.readDateOrNull(json['eta'], '$path.eta'),
      trackingNumber: J.readIdOrNull(
        json['trackingNumber'],
        '$path.trackingNumber',
      ),
      contactPhoneLast4: J.readIdOrNull(
        json['contactPhoneLast4'],
        '$path.contactPhoneLast4',
      ),
    );
  }
}

final class OrderHistoryPage with ValueJson {
  const OrderHistoryPage({required this.orders, this.nextCursor});

  final List<Order> orders;

  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'orders': <Object?>[for (final order in orders) order.toJson()],
    if (nextCursor != null) 'nextCursor': nextCursor,
  };

  factory OrderHistoryPage.fromJson(JsonMap json, [String path = r'$']) {
    final ordersJson = json['orders'] == null
        ? const <Object?>[]
        : J.readList(json['orders'], '$path.orders');
    return OrderHistoryPage(
      orders: <Order>[
        for (var i = 0; i < ordersJson.length; i++)
          Order.fromJson(
            J.readObject(ordersJson[i], '$path.orders[$i]'),
            '$path.orders[$i]',
          ),
      ],
      nextCursor: J.readIdOrNull(json['nextCursor'], '$path.nextCursor'),
    );
  }
}

final class ContactInfo with ValueJson {
  const ContactInfo({required this.name, required this.phone, this.email});

  final String name;

  final String phone;

  final String? email;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'phone': phone,
    if (email != null) 'email': email,
  };

  factory ContactInfo.fromJson(JsonMap json, [String path = r'$']) =>
      ContactInfo(
        name: J.readString(json['name'], '$path.name'),
        phone: J.readString(json['phone'], '$path.phone'),
        email: J.readIdOrNull(json['email'], '$path.email'),
      );
}

final class OrderLineRequest with ValueJson {
  const OrderLineRequest({required this.designId, this.quantity = 1});

  final String designId;

  final int quantity;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'designId': designId,
    'quantity': quantity,
  };

  factory OrderLineRequest.fromJson(JsonMap json, [String path = r'$']) =>
      OrderLineRequest(
        designId: J.readId(json['designId'], '$path.designId'),
        quantity: J.readIntOrNull(json['quantity'], '$path.quantity') ?? 1,
      );
}

final class CheckoutRequest with ValueJson {
  const CheckoutRequest({
    required this.cartId,
    required this.delivery,
    required this.contact,
    this.promoCode,
  });

  final String cartId;

  final DeliverySelection delivery;

  final ContactInfo contact;

  final String? promoCode;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'cartId': cartId,
    'delivery': delivery.toJson(),
    'contact': contact.toJson(),
    if (promoCode != null) 'promoCode': promoCode,
  };

  factory CheckoutRequest.fromJson(JsonMap json, [String path = r'$']) =>
      CheckoutRequest(
        cartId: J.readId(json['cartId'], '$path.cartId'),
        delivery: DeliverySelection.fromJson(
          J.readObject(json['delivery'], '$path.delivery'),
          '$path.delivery',
        ),
        contact: ContactInfo.fromJson(
          J.readObject(json['contact'], '$path.contact'),
          '$path.contact',
        ),
        promoCode: J.readIdOrNull(json['promoCode'], '$path.promoCode'),
      );
}

final class CreateOrderRequest with ValueJson {
  const CreateOrderRequest({
    required this.lines,
    required this.delivery,
    required this.contact,
    this.promoCode,
  });

  final List<OrderLineRequest> lines;

  final DeliverySelection delivery;

  final ContactInfo contact;

  final String? promoCode;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'lines': <Object?>[for (final line in lines) line.toJson()],
    'delivery': delivery.toJson(),
    'contact': contact.toJson(),
    if (promoCode != null) 'promoCode': promoCode,
  };

  factory CreateOrderRequest.fromJson(JsonMap json, [String path = r'$']) {
    final linesJson = json['lines'] == null
        ? const <Object?>[]
        : J.readList(json['lines'], '$path.lines');
    return CreateOrderRequest(
      lines: <OrderLineRequest>[
        for (var i = 0; i < linesJson.length; i++)
          OrderLineRequest.fromJson(
            J.readObject(linesJson[i], '$path.lines[$i]'),
            '$path.lines[$i]',
          ),
      ],
      delivery: DeliverySelection.fromJson(
        J.readObject(json['delivery'], '$path.delivery'),
        '$path.delivery',
      ),
      contact: ContactInfo.fromJson(
        J.readObject(json['contact'], '$path.contact'),
        '$path.contact',
      ),
      promoCode: J.readIdOrNull(json['promoCode'], '$path.promoCode'),
    );
  }
}
