import '../json.dart';
import '../money.dart';
import 'pricing.dart';

final class CartItem with ValueJson {
  const CartItem({
    required this.id,
    required this.designId,
    required this.quantity,
    required this.quote,
  });

  final String id;

  final String designId;

  final int quantity;

  final PriceQuote quote;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'designId': designId,
    'quantity': quantity,
    'quote': quote.toJson(),
  };

  factory CartItem.fromJson(JsonMap json, [String path = r'$']) => CartItem(
    id: J.readId(json['id'], '$path.id'),
    designId: J.readId(json['designId'], '$path.designId'),
    quantity: J.readInt(json['quantity'], '$path.quantity'),
    quote: PriceQuote.fromJson(
      J.readObject(json['quote'], '$path.quote'),
      '$path.quote',
    ),
  );
}

final class Cart with ValueJson {
  const Cart({
    required this.id,
    required this.items,
    required this.expiresAt,
    required this.subtotal,
    this.promoCode,
    this.canCheckout = true,
  });

  final String id;

  final List<CartItem> items;

  final DateTime expiresAt;

  final Money subtotal;

  final String? promoCode;

  final bool canCheckout;

  bool get isEmpty => items.isEmpty;

  int get unitCount => items.fold(0, (sum, item) => sum + item.quantity);

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'items': <Object?>[for (final item in items) item.toJson()],
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'subtotal': subtotal.toJson(),
    if (promoCode != null) 'promoCode': promoCode,
    'canCheckout': canCheckout,
  };

  factory Cart.fromJson(JsonMap json, [String path = r'$']) {
    final itemsJson = json['items'] == null
        ? const <Object?>[]
        : J.readList(json['items'], '$path.items');
    return Cart(
      id: J.readId(json['id'], '$path.id'),
      items: <CartItem>[
        for (var i = 0; i < itemsJson.length; i++)
          CartItem.fromJson(
            J.readObject(itemsJson[i], '$path.items[$i]'),
            '$path.items[$i]',
          ),
      ],
      expiresAt: J.readDate(json['expiresAt'], '$path.expiresAt'),
      subtotal: Money.nonNegativeFromJson(json['subtotal'], '$path.subtotal'),
      promoCode: J.readIdOrNull(json['promoCode'], '$path.promoCode'),
      canCheckout: J.readBoolOr(
        json['canCheckout'],
        '$path.canCheckout',
        fallback: true,
      ),
    );
  }
}

final class AddCartItemRequest with ValueJson {
  const AddCartItemRequest({required this.designId, this.quantity = 1});

  final String designId;

  final int quantity;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'designId': designId,
    'quantity': quantity,
  };

  factory AddCartItemRequest.fromJson(JsonMap json, [String path = r'$']) =>
      AddCartItemRequest(
        designId: J.readId(json['designId'], '$path.designId'),
        quantity: J.readIntOrNull(json['quantity'], '$path.quantity') ?? 1,
      );
}

final class UpdateCartItemRequest with ValueJson {
  const UpdateCartItemRequest({
    required this.itemId,
    this.quantity,
    this.promoCode,
  });

  final String itemId;

  final int? quantity;

  final String? promoCode;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'itemId': itemId,
    if (quantity != null) 'quantity': quantity,
    if (promoCode != null) 'promoCode': promoCode,
  };

  factory UpdateCartItemRequest.fromJson(JsonMap json, [String path = r'$']) =>
      UpdateCartItemRequest(
        itemId: J.readId(json['itemId'], '$path.itemId'),
        quantity: J.readIntOrNull(json['quantity'], '$path.quantity'),
        promoCode: J.readIdOrNull(json['promoCode'], '$path.promoCode'),
      );
}
