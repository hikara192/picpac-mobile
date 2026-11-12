import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di.dart';
import '../session/guest_work.dart';
import '../session/session_service.dart';
import 'cart_pricing.dart';

final class CartContext {
  const CartContext({
    required this.cart,
    this.catalog,
    this.designs = const <String, DesignDto>{},
    this.reconciled = false,
  });

  final Cart cart;

  final CatalogResponse? catalog;

  final Map<String, DesignDto> designs;

  final bool reconciled;

  Product? productOf(String designId) {
    final document = designs[designId]?.document;
    if (document == null) return null;
    for (final product in catalog?.products ?? const <Product>[]) {
      if (product.id == document.product.id) return product;
    }
    return null;
  }

  ProductFormat? formatOf(String designId) {
    final document = designs[designId]?.document;
    if (document == null) return null;
    final product = productOf(designId);
    if (product == null) return null;
    for (final format in product.formats) {
      if (format.id == document.product.formatId) return format;
    }
    return null;
  }

  String? titleOf(String designId) {
    final product = productOf(designId);
    if (product == null) return null;
    final format = formatOf(designId);
    return format == null ? product.title : '${product.title} ${format.title}';
  }

  bool isUnavailable(String designId) => !designs.containsKey(designId);

  PricingUnit unitOf(String designId) {
    final format = formatOf(designId);
    return format == null ? PricingUnit.sheet : pricingUnitOf(format);
  }

  int? sheetsOf(String designId) {
    final document = designs[designId]?.document;
    return document == null ? null : sheetCountOf(document);
  }

  int unitsOf(CartItem item) {
    final format = formatOf(item.designId);
    final document = designs[item.designId]?.document;
    if (format == null || document == null) return item.quantity;
    return pricingUnits(
      format: format,
      quantity: item.quantity,
      documentSpreads: sheetCountOf(document),
    );
  }

  CartContext withCart(Cart refreshed, {bool? reconciled}) => CartContext(
    cart: refreshed,
    catalog: catalog,
    designs: designs,
    reconciled: reconciled ?? this.reconciled,
  );
}

final class CartRepository {
  CartRepository({
    required this._api,
    required this._session,
    this._onCartSeen,
  });

  final ApiPort _api;
  final SessionService _session;
  final void Function(String cartId, UserRole role)? _onCartSeen;

  CatalogResponse? _catalog;

  Map<String, DesignDto> _designs = const <String, DesignDto>{};

  String? _signature;

  void clearCache() {
    _catalog = null;
    _designs = const <String, DesignDto>{};
    _signature = null;
  }

  Future<Result<CartContext>> load({bool force = false}) async {
    final cartResult = await _session.ensureSession(_api.cart);
    final cart = cartResult.fold(
      ok: (value) => value,
      err: (failure) => throw failure,
    );
    _onCartSeen?.call(cart.id, _session.role);
    if (cart.items.isEmpty) {
      clearCache();
      return Ok<CartContext>(CartContext(cart: cart));
    }
    final signature = _signatureOf(cart);
    final cachedCatalog = _catalog;
    if (!force && cachedCatalog != null && _signature == signature) {
      return Ok<CartContext>(
        CartContext(cart: cart, catalog: cachedCatalog, designs: _designs),
      );
    }

    final catalogResult = await _api.catalog();
    final catalog = catalogResult.valueOrNull;
    final designs = <String, DesignDto>{};
    final designResults = await Future.wait<Result<DesignDto>>(
      cart.items.map((item) => _api.design(item.designId)),
    );
    for (var i = 0; i < designResults.length; i++) {
      final design = designResults[i].valueOrNull;
      if (design != null) designs[cart.items[i].designId] = design;
    }

    var current = cart;
    var reconciled = false;
    for (final item in cart.items) {
      final document = designs[item.designId]?.document;
      if (document == null) continue;
      final product = _productOf(catalog, document.product.id);
      final format = _formatOf(product, document.product.formatId);
      if (format == null || !pricingUnitOf(format).isSheet) continue;
      final expected = clampQuantity(sheetCountOf(document));
      if (expected == item.quantity) continue;
      final patched = await _session.ensureSession(
        () => _api.updateCartItem(
          UpdateCartItemRequest(itemId: item.id, quantity: expected),
        ),
      );
      if (patched case Ok<Cart>(:final value)) {
        current = value;
        reconciled = true;
      }
    }

    _catalog = catalog;
    _designs = designs;
    _signature = reconciled ? null : signature;
    return Ok<CartContext>(
      CartContext(
        cart: current,
        catalog: catalog,
        designs: designs,
        reconciled: reconciled,
      ),
    );
  }

  static String _signatureOf(Cart cart) =>
      cart.items.map((item) => '${item.designId}:${item.quantity}').join('|');

  Future<Result<Cart>> setQuantity(String itemId, int quantity) =>
      _session.ensureSession(
        () => _api.updateCartItem(
          UpdateCartItemRequest(itemId: itemId, quantity: quantity),
        ),
      );

  Future<Result<Cart>> setPromo(String? code) async {
    final cartResult = await _session.ensureSession(_api.cart);
    final cart = cartResult.fold(
      ok: (value) => value,
      err: (failure) => throw failure,
    );
    if (cart.items.isEmpty) {
      return Err<Cart>(
        const ApiFailure(
          code: ApiErrorCode.validationFailed,
          message: 'the cart is empty',
          statusCode: 422,
        ),
      );
    }
    return _session.ensureSession(
      () => _api.updateCartItem(
        UpdateCartItemRequest(itemId: cart.items.first.id, promoCode: code),
      ),
    );
  }

  Future<Result<Cart>> remove(String itemId) =>
      _session.ensureSession(() => _api.removeCartItem(itemId));

  Product? _productOf(CatalogResponse? catalog, String productId) {
    for (final product in catalog?.products ?? const <Product>[]) {
      if (product.id == productId) return product;
    }
    return null;
  }

  ProductFormat? _formatOf(Product? product, String formatId) {
    for (final format in product?.formats ?? const <ProductFormat>[]) {
      if (format.id == formatId) return format;
    }
    return null;
  }
}

final Provider<CartRepository> cartRepositoryProvider =
    Provider<CartRepository>(
      (ref) => CartRepository(
        api: ref.watch(apiPortProvider),
        session: ref.watch(sessionServiceProvider),
        onCartSeen: (cartId, role) => ref
            .read(guestWorkProvider.notifier)
            .rememberCart(cartId, role: role),
      ),
    );

final class CartRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final cartRevisionProvider = NotifierProvider<CartRevision, int>(
  CartRevision.new,
);
