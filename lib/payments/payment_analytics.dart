import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/di.dart';
import '../core/analytics.dart';
import '../core/app_logger.dart';
import 'payment_method.dart';

final class PaymentAnalytics {
  PaymentAnalytics(this._analytics, this._logger);

  final Analytics _analytics;
  final AppLogger _logger;

  void methodsLoaded({required String region, required int count}) {
    _logger.debug('payments.methods', <String, Object?>{
      'region': region,
      'count': count,
    });
  }

  void attemptCreated({
    required String provider,
    required PaymentMethodKind methodKind,
    required PaymentStatus status,
    required Money amount,
  }) {
    _analytics.track(AnalyticsEvent.paymentStarted, <String, Object?>{
      'provider': provider,
      'methodKind': methodKind.wire,
      'status': status.wire,
      'amountMinor': amount.amountMinor,
      'currency': amount.currency,
    });
  }

  void attemptFailed(Failure failure) {
    _logger.warning('payments.create.failed', <String, Object?>{
      'code': failure.code,
    });
  }

  void hostedPageOpened({required String provider}) {
    _logger.debug('payments.hosted.opened', <String, Object?>{
      'provider': provider,
    });
  }
}

final Provider<PaymentAnalytics> paymentAnalyticsProvider =
    Provider<PaymentAnalytics>(
      (ref) => PaymentAnalytics(
        ref.watch(analyticsProvider),
        ref.watch(loggerProvider),
      ),
    );
