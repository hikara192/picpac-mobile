import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/di.dart';

abstract interface class PaymentPort {
  Future<Result<List<PaymentMethodInfo>>> methods(String region);

  Future<Result<PaymentIntent>> createIntent({
    required String orderId,
    required String methodId,
    required String region,
    required String idempotencyKey,
  });

  Future<Result<PaymentIntent>> status(String intentId);

  Future<Result<Receipt>> receipt(String orderId);
}

final class ApiPaymentPort implements PaymentPort {
  const ApiPaymentPort(this._api);

  final ApiPort _api;

  @override
  Future<Result<List<PaymentMethodInfo>>> methods(String region) =>
      _api.paymentMethods(region: region);

  @override
  Future<Result<PaymentIntent>> createIntent({
    required String orderId,
    required String methodId,
    required String region,
    required String idempotencyKey,
  }) => _api.createPaymentIntent(
    CreatePaymentIntentRequest(
      orderId: orderId,
      methodId: methodId,
      region: region,
    ),
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<Result<PaymentIntent>> status(String intentId) =>
      _api.paymentIntent(intentId);

  @override
  Future<Result<Receipt>> receipt(String orderId) => _api.receipt(orderId);
}

final Provider<PaymentPort> paymentPortProvider = Provider<PaymentPort>(
  (ref) => ApiPaymentPort(ref.watch(apiPortProvider)),
);
