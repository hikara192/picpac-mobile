import 'package:api_contract/api_contract.dart';
import 'package:picpac_mobile/payments/hosted_page_launcher.dart';
import 'package:picpac_mobile/payments/payment_port.dart';

final class FakePaymentPort implements PaymentPort {
  FakePaymentPort({
    required this.methodsByRegion,
    required this.onCreate,
    required this.onStatus,
    this.onReceipt,
  });

  final Map<String, List<PaymentMethodInfo>> methodsByRegion;

  final Future<Result<PaymentIntent>> Function(String key) onCreate;

  final Future<Result<PaymentIntent>> Function(String intentId) onStatus;

  final Future<Result<Receipt>> Function(String orderId)? onReceipt;

  final List<String> methodRegions = <String>[];

  final List<String> createKeys = <String>[];

  final List<String> statusCalls = <String>[];

  @override
  Future<Result<List<PaymentMethodInfo>>> methods(String region) async {
    methodRegions.add(region);
    return Ok<List<PaymentMethodInfo>>(
      methodsByRegion[region] ?? const <PaymentMethodInfo>[],
    );
  }

  @override
  Future<Result<PaymentIntent>> createIntent({
    required String orderId,
    required String methodId,
    required String region,
    required String idempotencyKey,
  }) {
    createKeys.add(idempotencyKey);
    return onCreate(idempotencyKey);
  }

  @override
  Future<Result<PaymentIntent>> status(String intentId) {
    statusCalls.add(intentId);
    return onStatus(intentId);
  }

  @override
  Future<Result<Receipt>> receipt(String orderId) =>
      onReceipt?.call(orderId) ??
      Future<Result<Receipt>>.value(
        Err<Receipt>(
          const ApiFailure(code: 'not_found', message: 'no receipt'),
        ),
      );
}

final class FakeLauncher implements HostedPageLauncher {
  FakeLauncher({this.outcome = HostedPageLaunch.launched});

  final HostedPageLaunch outcome;

  final List<Uri> opened = <Uri>[];

  @override
  Future<HostedPageLaunch> open(Uri url) async {
    opened.add(url);
    return outcome;
  }
}

PaymentMethodInfo cardMethod({String region = 'BY', String currency = 'BYN'}) =>
    PaymentMethodInfo(
      id: 'bank_card',
      titleKey: 'payment.method.card',
      kind: 'card',
      currency: currency,
      region: region,
      requiresRedirect: true,
    );

PaymentMethodInfo eripMethod() => const PaymentMethodInfo(
  id: 'erip',
  titleKey: 'payment.method.erip',
  kind: 'erip',
  currency: 'BYN',
  region: 'BY',
  requiresRedirect: false,
);

PaymentMethodInfo codMethod() => const PaymentMethodInfo(
  id: 'cash_on_delivery',
  titleKey: 'payment.method.cod',
  kind: 'cod',
  currency: 'BYN',
  region: 'BY',
  requiresRedirect: false,
);

PaymentMethodInfo sbpMethod() => const PaymentMethodInfo(
  id: 'sbp',
  titleKey: 'payment.method.sbp',
  kind: 'sbp',
  currency: 'RUB',
  region: 'RU',
  requiresRedirect: true,
);
