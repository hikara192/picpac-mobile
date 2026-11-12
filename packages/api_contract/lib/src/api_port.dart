import 'package:design_core/design_core.dart' show DesignDocument, Err, Result;

import 'failure.dart';
import 'dto/ai.dart';
import 'dto/audit.dart';
import 'dto/auth.dart';
import 'dto/cart.dart';
import 'dto/catalog.dart';
import 'dto/delivery.dart';
import 'dto/designs.dart';
import 'dto/inspiration.dart';
import 'dto/orders.dart';
import 'dto/payments.dart';
import 'dto/pricing.dart';
import 'dto/support.dart';
import 'dto/uploads.dart';

abstract final class ApiPaths {
  static const String prefix = '/v1';

  static const String authAnonymous = '/auth/anonymous';

  static const String authLogin = '/auth/login';

  static const String authRegister = '/auth/register';

  static const String authVerify = '/auth/verify';

  static const String me = '/me';

  static const String catalog = '/catalog';

  static String product(String productId) => '/catalog/$productId';

  static String productFormats(String productId) =>
      '/catalog/$productId/formats';

  static const String price = '/price';

  static const String deliveryOptions = '/delivery/options';

  static const String pickupPoints = '/pickup/points';

  static const String uploadsPresign = '/uploads/presign';

  static String uploadComplete(String uploadId) =>
      '/uploads/$uploadId/complete';

  static String upload(String uploadId) => '/uploads/$uploadId';

  static const String designs = '/designs';

  static String design(String designId) => '/designs/$designId';

  static String designPreflight(String designId) =>
      '/designs/$designId/preflight';

  static const String inspiration = '/inspiration';

  static String inspirationItem(String inspirationId) =>
      '/inspiration/$inspirationId';

  static const String favorites = '/favorites';

  static String favorite(String inspirationId) => '/favorites/$inspirationId';

  static const String cart = '/cart';

  static const String cartItems = '/cart/items';

  static String cartItem(String itemId) => '/cart/items/$itemId';

  static const String checkout = '/checkout';

  static const String orders = '/orders';

  static String order(String orderId) => '/orders/$orderId';

  static const String ordersLookup = '/orders/lookup';

  static String orderClaim(String orderId) => '/orders/$orderId/claim';

  static const String paymentMethods = '/payments/methods';

  static String orderPaymentIntent(String orderId) =>
      '/orders/$orderId/payment-intent';

  static String paymentIntent(String intentId) => '/payments/$intentId';

  static String orderRefunds(String orderId) => '/orders/$orderId/refunds';

  static String orderReceipt(String orderId) => '/orders/$orderId/receipt';

  static const String supportTickets = '/support/tickets';

  static String supportTicket(String ticketId) => '/support/tickets/$ticketId';

  static String supportTicketMessages(String ticketId) =>
      '/support/tickets/$ticketId/messages';

  static const String audit = '/audit';

  static String pspWebhook(String provider) => '/webhooks/psp/$provider';

  static const String pspSimulate = '/mock/psp/simulate';

  static const String devices = '/devices';

  static const String aiPatch = '/ai/patch';
}

abstract class ApiPort {

  Future<Result<AuthSession>> createAnonymousSession(
    AnonymousSessionRequest request,
  );

  Future<Result<AuthSession>> login(LoginRequest request);

  Future<Result<AuthSession>> register(RegisterRequest request) async =>
      Err<AuthSession>(
        const ApiFailure(code: 'unsupported', message: 'register is not implemented'),
      );

Future<Result<AuthSession>> verifyCode({
    required String challengeId,
    required String code,
  });

  Future<Result<Customer>> currentCustomer();

  Future<Result<void>> deleteAccount();


  Future<Result<CatalogResponse>> catalog();

  Future<Result<Product>> product(String productId);

  Future<Result<List<ProductFormat>>> formats(String productId);


  Future<Result<PriceQuote>> price(PriceRequest request);


  Future<Result<List<DeliveryOption>>> deliveryOptions();

  Future<Result<List<PickupPoint>>> pickupPoints();


  Future<Result<UploadTicket>> presignUpload(PresignUploadRequest request);

  Future<Result<CompletedUpload>> completeUpload({
    required String uploadId,
    required String sha256,
  });

  Future<Result<void>> deleteUpload(String uploadId);


  Future<Result<DesignDto>> createDesign(DesignDocument document);

  Future<Result<DesignDto>> design(String designId);

  Future<Result<DesignDto>> putDesign(
    String designId,
    DesignDocument document, {
    required int ifMatchRevision,
  });

  Future<Result<void>> deleteDesign(String designId);

  Future<Result<PreflightDto>> preflight(String designId, {int? revision});


  Future<Result<InspirationFeedPage>> inspirationFeed({
    String? tag,
    String? cursor,
    int? limit,
  });

  Future<Result<InspirationDetail>> inspirationItem(String inspirationId);

  Future<Result<InspirationFeedPage>> favorites();

  Future<Result<FavoriteState>> addFavorite(String inspirationId);

  Future<Result<void>> removeFavorite(String inspirationId);


  Future<Result<Cart>> cart();

  Future<Result<Cart>> addCartItem(AddCartItemRequest request);

  Future<Result<Cart>> updateCartItem(UpdateCartItemRequest request);

  Future<Result<Cart>> removeCartItem(String itemId);


  Future<Result<Order>> checkout(
    CheckoutRequest request, {
    required String idempotencyKey,
  });

  Future<Result<Order>> createOrder(
    CreateOrderRequest request, {
    required String idempotencyKey,
  });

  Future<Result<OrderHistoryPage>> orders({
    OrderStatus? status,
    String? cursor,
    int? limit,
  });

  Future<Result<Order>> order(String orderId);

  Future<Result<Order>> lookupOrder({
    required String number,
    required String phoneLast4,
  });

  Future<Result<Order>> claimOrder(
    String orderId, {
    required String idempotencyKey,
  });


  Future<Result<List<PaymentMethodInfo>>> paymentMethods({
    required String region,
  });

  Future<Result<PaymentIntent>> createPaymentIntent(
    CreatePaymentIntentRequest request, {
    required String idempotencyKey,
  });

  Future<Result<PaymentIntent>> paymentIntent(String intentId);

  Future<Result<Refund>> refund(
    RefundRequest request, {
    required String idempotencyKey,
  });

  Future<Result<Receipt>> receipt(String orderId);


  Future<Result<List<SupportTicket>>> supportTickets({
    String? orderId,
    TicketStatus? status,
  });

  Future<Result<SupportTicket>> createSupportTicket(
    CreateTicketRequest request, {
    required String idempotencyKey,
  });

  Future<Result<SupportTicket>> supportTicket(String ticketId);

  Future<Result<SupportTicket>> postTicketMessage(
    PostTicketMessageRequest request, {
    required String idempotencyKey,
  });


  Future<Result<AiPatchResponse>> aiPatch(AiPatchRequest request);


  Future<Result<List<AuditRecord>>> auditRecords({
    String? actorId,
    String? objectType,
    String? objectId,
    int? limit,
  });
}
