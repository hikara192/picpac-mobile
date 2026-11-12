import 'package:dio/dio.dart';
import 'package:api_contract/api_contract.dart';

import '../core/app_logger.dart';
import 'auth_interceptor.dart';
import 'token_store.dart';

final class HttpApi implements ApiPort {
  HttpApi({
    required String baseUrl,
    required this._tokens,
    this._logger = const AppLogger(),
    Dio? dio,
  }) {
    _dio =
        dio ??
        Dio(
          BaseOptions(
            baseUrl: '$baseUrl${ApiPaths.prefix}',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
            responseType: ResponseType.json,
            headers: const <String, Object?>{'Accept': 'application/json'},
            validateStatus: (status) => status != null && status < 400,
          ),
        );
    _dio.interceptors.add(authInterceptor(_tokens));
  }

  final TokenStore _tokens;
  final AppLogger _logger;
  late final Dio _dio;


  Future<Result<T>> _get<T>(
    String path,
    T Function(JsonMap json) parse, {
    Map<String, Object?>? query,
    bool retry = false,
  }) => _run(
    () => _dio.get<Object?>(path, queryParameters: _clean(query)),
    parse,
    retryable: retry,
  );

  Future<Result<T>> _post<T>(
    String path, {
    Object? body,
    required T Function(JsonMap json) parse,
    String? idempotencyKey,
    bool retryable = false,
  }) => _run(
    () => _dio.post<Object?>(
      path,
      data: body,
      options: Options(headers: _idempotency(idempotencyKey)),
    ),
    parse,
    retryable: retryable,
    idempotencyKey: idempotencyKey,
  );

  Future<Result<T>> _put<T>(
    String path, {
    Object? body,
    required T Function(JsonMap json) parse,
    int? ifMatchRevision,
  }) => _run(
    () => _dio.put<Object?>(
      path,
      data: body,
      options: Options(
        headers: <String, Object?>{
          if (ifMatchRevision != null) 'If-Match': '$ifMatchRevision',
        },
      ),
    ),
    parse,
  );

  Future<Result<T>> _patch<T>(
    String path, {
    Object? body,
    required T Function(JsonMap json) parse,
  }) => _run(() => _dio.patch<Object?>(path, data: body), parse);

  Future<Result<void>> _delete(String path) async {
    try {
      await _dio.delete<Object?>(path);
      return const Ok<void>(null);
    } on DioException catch (error) {
      return Err<void>(_mapError(error));
    }
  }

  Future<Result<T>> _run<T>(
    Future<Response<Object?>> Function() request,
    T Function(JsonMap json) parse, {
    bool retryable = false,
    String? idempotencyKey,
    int attempt = 0,
  }) async {
    try {
      final response = await request();
      final data = response.data;
      if (data == null) {
        return Err<T>(
          ApiFailure.invalidResponse(message: 'empty response body'),
        );
      }
      return decodeJson(data, parse);
    } on DioException catch (error) {
      final failure = _mapError(error);
      if (retryable && failure.isRetryable && attempt < 1) {
        return _run(
          request,
          parse,
          retryable: retryable,
          idempotencyKey: idempotencyKey,
          attempt: attempt + 1,
        );
      }
      return Err<T>(failure);
    }
  }

  Map<String, Object?> _idempotency(String? explicit) => <String, Object?>{
    'Idempotency-Key': ?explicit,
  };

  Map<String, Object?>? _clean(Map<String, Object?>? query) {
    if (query == null) return null;
    final cleaned = <String, Object?>{
      for (final entry in query.entries)
        if (entry.value != null) entry.key: entry.value,
    };
    return cleaned.isEmpty ? null : cleaned;
  }

  ApiFailure _mapError(DioException error) {
    final response = error.response;
    final data = response?.data;
    if (data is Map) {
      try {
        return ApiFailure.fromJson(Map<String, Object?>.from(data));
      } on Object {
      }
    }
    final status = response?.statusCode;
    if (status != null) {
      return switch (status) {
        401 => const ApiFailure(
          code: ApiErrorCode.unauthorized,
          message: 'unauthorized',
          statusCode: 401,
        ),
        403 => const ApiFailure(
          code: ApiErrorCode.forbidden,
          message: 'forbidden',
          statusCode: 403,
        ),
        404 => const ApiFailure(
          code: ApiErrorCode.notFound,
          message: 'not found',
          statusCode: 404,
        ),
        409 => const ApiFailure(
          code: ApiErrorCode.conflictRevision,
          message: 'revision conflict',
          statusCode: 409,
        ),
        422 => const ApiFailure(
          code: ApiErrorCode.validationFailed,
          message: 'validation failed',
          statusCode: 422,
        ),
        429 => const ApiFailure(
          code: ApiErrorCode.rateLimited,
          message: 'rate limited',
          statusCode: 429,
        ),
        >= 500 => ApiFailure(
          code: ApiErrorCode.serverError,
          message: 'server error',
          statusCode: status,
        ),
        _ => ApiFailure(
          code: ApiErrorCode.serverError,
          message: 'unexpected status $status',
          statusCode: status,
        ),
      };
    }
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => ApiFailure.timeout(),
      DioExceptionType.badCertificate => const ApiFailure(
        code: ApiErrorCode.serverError,
        message: 'certificate rejected',
      ),
      _ => ApiFailure.networkUnavailable(),
    };
  }

  void _logFailure(String operation, Failure failure) {
    _logger.warning('api.$operation.failed', <String, Object?>{
      'code': failure.code,
      if (failure is ApiFailure && failure.statusCode != null)
        'status': failure.statusCode,
    });
  }


  @override
  Future<Result<AuthSession>> createAnonymousSession(
    AnonymousSessionRequest request,
  ) async {
    final result = await _post<AuthSession>(
      ApiPaths.authAnonymous,
      body: request.toJson(),
      parse: AuthSession.fromJson,
    );
    return _persist(result, 'auth.anonymous');
  }

  @override
  Future<Result<AuthSession>> register(RegisterRequest request) async {
    final result = await _post<AuthSession>(
      ApiPaths.authRegister,
      body: request.toJson(),
      parse: AuthSession.fromJson,
    );
    return _persist(result, 'auth.register');
  }

  @override
  Future<Result<AuthSession>> login(LoginRequest request) async {
    final result = await _post<AuthSession>(
      ApiPaths.authLogin,
      body: request.toJson(),
      parse: AuthSession.fromJson,
    );
    return _persist(result, 'auth.login');
  }

  @override
  Future<Result<AuthSession>> verifyCode({
    required String challengeId,
    required String code,
  }) async {
    final result = await _post<AuthSession>(
      ApiPaths.authVerify,
      body: <String, Object?>{'challengeId': challengeId, 'code': code},
      parse: AuthSession.fromJson,
    );
    return _persist(result, 'auth.verify');
  }

  Future<Result<AuthSession>> _persist(
    Result<AuthSession> result,
    String operation,
  ) async {
    switch (result) {
      case Ok<AuthSession>(:final value):
        await _tokens.save(value);
        return Ok<AuthSession>(value);
      case Err<AuthSession>(:final error):
        _logFailure(operation, error);
        return Err<AuthSession>(error);
    }
  }

  @override
  Future<Result<Customer>> currentCustomer() =>
      _get<Customer>(ApiPaths.me, Customer.fromJson);

  @override
  Future<Result<void>> deleteAccount() async {
    final result = await _delete(ApiPaths.me);
    if (result is Ok<void>) await _tokens.clear();
    return result;
  }


  @override
  Future<Result<CatalogResponse>> catalog() => _get<CatalogResponse>(
    ApiPaths.catalog,
    CatalogResponse.fromJson,
    retry: true,
  );

  @override
  Future<Result<Product>> product(String productId) =>
      _get<Product>(ApiPaths.product(productId), Product.fromJson);

  @override
  Future<Result<List<ProductFormat>>> formats(String productId) =>
      _getList(ApiPaths.productFormats(productId), ProductFormat.fromJson);


  @override
  Future<Result<PriceQuote>> price(PriceRequest request) => _post<PriceQuote>(
    ApiPaths.price,
    body: request.toJson(),
    parse: PriceQuote.fromJson,
  );


  @override
  Future<Result<List<DeliveryOption>>> deliveryOptions() =>
      _getList<DeliveryOption>(
        ApiPaths.deliveryOptions,
        DeliveryOption.fromJson,
      );

  @override
  Future<Result<List<PickupPoint>>> pickupPoints() =>
      _getList(ApiPaths.pickupPoints, PickupPoint.fromJson);


  @override
  Future<Result<UploadTicket>> presignUpload(PresignUploadRequest request) =>
      _post<UploadTicket>(
        ApiPaths.uploadsPresign,
        body: request.toJson(),
        parse: UploadTicket.fromJson,
      );

  @override
  Future<Result<CompletedUpload>> completeUpload({
    required String uploadId,
    required String sha256,
  }) => _post<CompletedUpload>(
    ApiPaths.uploadComplete(uploadId),
    body: <String, Object?>{'sha256': sha256},
    parse: CompletedUpload.fromJson,
  );

  @override
  Future<Result<void>> deleteUpload(String uploadId) =>
      _delete(ApiPaths.upload(uploadId));


  @override
  Future<Result<DesignDto>> createDesign(DesignDocument document) =>
      _post<DesignDto>(
        ApiPaths.designs,
        body: document.toJson(),
        parse: DesignDto.fromJson,
      );

  @override
  Future<Result<DesignDto>> design(String designId) =>
      _get<DesignDto>(ApiPaths.design(designId), DesignDto.fromJson);

  @override
  Future<Result<DesignDto>> putDesign(
    String designId,
    DesignDocument document, {
    required int ifMatchRevision,
  }) => _put<DesignDto>(
    ApiPaths.design(designId),
    body: document.toJson(),
    parse: DesignDto.fromJson,
    ifMatchRevision: ifMatchRevision,
  );

  @override
  Future<Result<void>> deleteDesign(String designId) =>
      _delete(ApiPaths.design(designId));

  @override
  Future<Result<PreflightDto>> preflight(String designId, {int? revision}) =>
      _post<PreflightDto>(
        ApiPaths.designPreflight(designId),
        body: <String, Object?>{'revision': ?revision},
        parse: PreflightDto.fromJson,
      );


  @override
  Future<Result<InspirationFeedPage>> inspirationFeed({
    String? tag,
    String? cursor,
    int? limit,
  }) => _get<InspirationFeedPage>(
    ApiPaths.inspiration,
    InspirationFeedPage.fromJson,
    query: <String, Object?>{'tag': tag, 'cursor': cursor, 'limit': limit},
    retry: true,
  );

  @override
  Future<Result<InspirationDetail>> inspirationItem(String inspirationId) =>
      _get<InspirationDetail>(
        ApiPaths.inspirationItem(inspirationId),
        InspirationDetail.fromJson,
      );

  @override
  Future<Result<InspirationFeedPage>> favorites() => _get<InspirationFeedPage>(
    ApiPaths.favorites,
    InspirationFeedPage.fromJson,
  );

  @override
  Future<Result<FavoriteState>> addFavorite(String inspirationId) =>
      _post<FavoriteState>(
        ApiPaths.favorite(inspirationId),
        parse: FavoriteState.fromJson,
      );

  @override
  Future<Result<void>> removeFavorite(String inspirationId) =>
      _delete(ApiPaths.favorite(inspirationId));


  @override
  Future<Result<Cart>> cart() => _get<Cart>(ApiPaths.cart, Cart.fromJson);

  @override
  Future<Result<Cart>> addCartItem(AddCartItemRequest request) => _post<Cart>(
    ApiPaths.cartItems,
    body: request.toJson(),
    parse: Cart.fromJson,
  );

  @override
  Future<Result<Cart>> updateCartItem(UpdateCartItemRequest request) =>
      _patch<Cart>(
        ApiPaths.cartItem(request.itemId),
        body: request.toJson(),
        parse: Cart.fromJson,
      );

  @override
  Future<Result<Cart>> removeCartItem(String itemId) => _run<Cart>(
    () => _dio.delete<Object?>(ApiPaths.cartItem(itemId)),
    Cart.fromJson,
  );


  @override
  Future<Result<Order>> checkout(
    CheckoutRequest request, {
    required String idempotencyKey,
  }) => _post<Order>(
    ApiPaths.checkout,
    body: request.toJson(),
    parse: Order.fromJson,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<Result<Order>> createOrder(
    CreateOrderRequest request, {
    required String idempotencyKey,
  }) => _post<Order>(
    ApiPaths.orders,
    body: request.toJson(),
    parse: Order.fromJson,
    idempotencyKey: idempotencyKey,
  );


  @override
  Future<Result<OrderHistoryPage>> orders({
    OrderStatus? status,
    String? cursor,
    int? limit,
  }) => _get<OrderHistoryPage>(
    ApiPaths.orders,
    OrderHistoryPage.fromJson,
    query: <String, Object?>{
      'status': status?.wire,
      'cursor': cursor,
      'limit': limit,
    },
  );

  @override
  Future<Result<Order>> order(String orderId) =>
      _get<Order>(ApiPaths.order(orderId), Order.fromJson);

  @override
  Future<Result<Order>> lookupOrder({
    required String number,
    required String phoneLast4,
  }) => _post<Order>(
    ApiPaths.ordersLookup,
    body: <String, Object?>{'number': number, 'phoneLast4': phoneLast4},
    parse: Order.fromJson,
  );

  @override
  Future<Result<Order>> claimOrder(
    String orderId, {
    required String idempotencyKey,
  }) => _post<Order>(
    ApiPaths.orderClaim(orderId),
    parse: Order.fromJson,
    idempotencyKey: idempotencyKey,
  );


  @override
  Future<Result<List<PaymentMethodInfo>>> paymentMethods({
    required String region,
  }) => _getList(
    ApiPaths.paymentMethods,
    PaymentMethodInfo.fromJson,
    query: <String, Object?>{'region': region},
  );

  @override
  Future<Result<PaymentIntent>> createPaymentIntent(
    CreatePaymentIntentRequest request, {
    required String idempotencyKey,
  }) => _post<PaymentIntent>(
    ApiPaths.orderPaymentIntent(request.orderId),
    body: request.toJson(),
    parse: PaymentIntent.fromJson,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<Result<PaymentIntent>> paymentIntent(String intentId) =>
      _get<PaymentIntent>(
        ApiPaths.paymentIntent(intentId),
        PaymentIntent.fromJson,
      );

  @override
  Future<Result<Refund>> refund(
    RefundRequest request, {
    required String idempotencyKey,
  }) => _post<Refund>(
    ApiPaths.orderRefunds(request.orderId),
    body: request.toJson(),
    parse: Refund.fromJson,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<Result<Receipt>> receipt(String orderId) =>
      _get<Receipt>(ApiPaths.orderReceipt(orderId), Receipt.fromJson);


  @override
  Future<Result<List<SupportTicket>>> supportTickets({
    String? orderId,
    TicketStatus? status,
  }) => _getList(
    ApiPaths.supportTickets,
    SupportTicket.fromJson,
    query: <String, Object?>{'orderId': orderId, 'status': status?.wire},
  );

  @override
  Future<Result<SupportTicket>> createSupportTicket(
    CreateTicketRequest request, {
    required String idempotencyKey,
  }) => _post<SupportTicket>(
    ApiPaths.supportTickets,
    body: request.toJson(),
    parse: SupportTicket.fromJson,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<Result<SupportTicket>> supportTicket(String ticketId) =>
      _get<SupportTicket>(
        ApiPaths.supportTicket(ticketId),
        SupportTicket.fromJson,
      );

  @override
  Future<Result<SupportTicket>> postTicketMessage(
    PostTicketMessageRequest request, {
    required String idempotencyKey,
  }) => _post<SupportTicket>(
    ApiPaths.supportTicketMessages(request.ticketId),
    body: request.toJson(),
    parse: SupportTicket.fromJson,
    idempotencyKey: idempotencyKey,
  );


  @override
  Future<Result<AiPatchResponse>> aiPatch(AiPatchRequest request) async {
    final result = await _post<AiPatchResponse>(
      ApiPaths.aiPatch,
      body: request.toJson(),
      parse: AiPatchResponse.fromJson,
    );
    if (result case Err<AiPatchResponse>(:final error)) {
      _logFailure('ai.patch', error);
    }
    return result;
  }


  @override
  Future<Result<List<AuditRecord>>> auditRecords({
    String? actorId,
    String? objectType,
    String? objectId,
    int? limit,
  }) => _getList(
    ApiPaths.audit,
    AuditRecord.fromJson,
    query: <String, Object?>{
      'actorId': actorId,
      'objectType': objectType,
      'objectId': objectId,
      'limit': limit,
    },
  );

  Future<Result<List<T>>> _getList<T>(
    String path,
    T Function(JsonMap json) parse, {
    Map<String, Object?>? query,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        path,
        queryParameters: _clean(query),
      );
      return decodeJsonList<T>(response.data, (json, _) => parse(json));
    } on DioException catch (error) {
      return Err<List<T>>(_mapError(error));
    }
  }
}
