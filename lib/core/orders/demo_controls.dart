import 'package:api_contract/api_contract.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di.dart';
import '../app_logger.dart';
import '../../network/auth_interceptor.dart';
import '../../network/token_store.dart';

final class DemoControlsConfig {
  const DemoControlsConfig({required this.baseUrl});

  final String baseUrl;
}

bool isDemoEndpointUnavailable(Failure failure) {
  if (isAdvanceNeedsSupport(failure)) return false;
  return failure.code == ApiErrorCode.forbidden ||
      failure.code == ApiErrorCode.notFound ||
      (failure is ApiFailure &&
          (failure.statusCode == 403 || failure.statusCode == 404));
}

bool isAdvanceNeedsSupport(Failure failure) =>
    failure.code == 'advance_requires_support';

abstract interface class DemoOrderControlsPort {
  Future<Result<Order>> advance(String orderId, {String? to});

  Future<Result<PaymentIntent>> simulateCardSuccess({required String orderId});

  Future<Result<void>> confirmHostedPayment(Uri hostedPageUrl);
}

final class HttpDemoOrderControls implements DemoOrderControlsPort {
  HttpDemoOrderControls({
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
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 10),
            responseType: ResponseType.json,
            validateStatus: (status) => status != null && status < 400,
          ),
        );
    _dio.interceptors.add(authInterceptor(_tokens));
  }

  final TokenStore _tokens;
  final AppLogger _logger;
  late final Dio _dio;

  @override
  Future<Result<Order>> advance(String orderId, {String? to}) => _run(
    () => _dio.post<Object?>(
      '/mock/orders/$orderId/advance',
      data: <String, Object?>{'to': ?to},
    ),
    Order.fromJson,
    'mock.orders.advance',
  );

  @override
  Future<Result<PaymentIntent>> simulateCardSuccess({
    required String orderId,
  }) => _run(
    () => _dio.post<Object?>(
      ApiPaths.pspSimulate,
      data: <String, Object?>{'scenario': 'card_success', 'orderId': orderId},
    ),
    (json) => PaymentIntent.fromJson(
      (json['intent'] as Map<String, Object?>?) ?? json,
    ),
    'mock.psp.simulate',
  );

  @override
  Future<Result<void>> confirmHostedPayment(Uri hostedPageUrl) async {
    final url = hostedPageUrl.replace(path: '${hostedPageUrl.path}/pay');
    try {
      await _dio.postUri<Object?>(url);
      return const Ok<void>(null);
    } on DioException catch (error) {
      final body = error.response?.data;
      final failure = body is Map
          ? ApiFailure.fromJson(Map<String, Object?>.from(body))
          : ApiFailure(
              code: ApiErrorCode.serverError,
              message: 'the hosted page refused the payment',
              statusCode: error.response?.statusCode,
            );
      _logger.warning('mock.psp.hosted_pay.failed', <String, Object?>{
        'code': failure.code,
      });
      return Err<void>(failure);
    }
  }

  Future<Result<T>> _run<T>(
    Future<Response<Object?>> Function() request,
    T Function(Map<String, Object?>) parse,
    String operation,
  ) async {
    try {
      final response = await request();
      final data = response.data;
      if (data is! Map) {
        return Err<T>(
          ApiFailure.invalidResponse(message: 'empty response body'),
        );
      }
      return decodeJson(Map<String, Object?>.from(data), parse);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final body = error.response?.data;
      final failure = body is Map
          ? ApiFailure.fromJson(Map<String, Object?>.from(body))
          : switch (status) {
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
                code: 'invalid_transition',
                message: 'invalid transition',
                statusCode: 409,
              ),
              422 => const ApiFailure(
                code: ApiErrorCode.validationFailed,
                message: 'validation failed',
                statusCode: 422,
              ),
              _ =>
                error.response == null
                    ? ApiFailure.networkUnavailable()
                    : ApiFailure(
                        code: ApiErrorCode.serverError,
                        message: 'mock control failed',
                        statusCode: status,
                      ),
            };
      _logger.warning('$operation.failed', <String, Object?>{
        'code': failure.code,
        'status': ?status,
      });
      return Err<T>(failure);
    }
  }
}

final Provider<DemoControlsConfig?> demoControlsConfigProvider =
    Provider<DemoControlsConfig?>((ref) => null);

final Provider<DemoOrderControlsPort?> demoOrderControlsProvider =
    Provider<DemoOrderControlsPort?>((ref) {
      final config = ref.watch(demoControlsConfigProvider);
      if (config == null) return null;
      return HttpDemoOrderControls(
        baseUrl: config.baseUrl,
        tokens: ref.watch(tokenStoreProvider),
        logger: ref.watch(loggerProvider),
      );
    });
