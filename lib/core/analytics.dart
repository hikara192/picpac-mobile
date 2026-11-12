import 'package:api_contract/api_contract.dart';

import 'app_logger.dart';

enum AnalyticsEvent {
  catalogViewed('catalog_viewed'),
  productOpened('product_opened'),
  projectCreated('project_created'),
  photoImported('photo_imported'),
  preflightShown('preflight_shown'),
  preflightOverridden('preflight_overridden'),
  cartViewed('cart_viewed'),
  checkoutStarted('checkout_started'),
  paymentStarted('payment_started'),
  orderCreated('order_created'),
  orderOpened('order_opened'),
  supportOpened('support_opened'),
  draftRestored('draft_restored'),
  pdfExported('pdf_exported');

  const AnalyticsEvent(this.wireName);

  final String wireName;
}

abstract interface class Analytics {
  void track(
    AnalyticsEvent event, [
    Map<String, Object?> attributes = const {},
  ]);
}

final class DebugAnalytics implements Analytics {
  DebugAnalytics([this._logger = const AppLogger(minLevel: LogLevel.debug)]);

  final AppLogger _logger;

  @override
  void track(
    AnalyticsEvent event, [
    Map<String, Object?> attributes = const {},
  ]) {
    _logger.debug('analytics.${event.wireName}', attributes);
  }
}

final class NoopAnalytics implements Analytics {
  const NoopAnalytics();

  @override
  void track(
    AnalyticsEvent event, [
    Map<String, Object?> attributes = const {},
  ]) {}
}

String messageKeyForFailure(Failure failure) {
  final code = failure.code;
  return switch (code) {
    ApiErrorCode.unauthorized => 'error.unauthorized',
    ApiErrorCode.forbidden => 'error.forbidden',
    ApiErrorCode.conflictRevision => 'error.conflictRevision',
    ApiErrorCode.idempotencyConflict => 'error.idempotencyConflict',
    ApiErrorCode.validationFailed => 'error.validation',
    ApiErrorCode.notFound => 'error.notFound',
    ApiErrorCode.rateLimited => 'error.rateLimited',
    ApiErrorCode.networkUnavailable => 'error.network',
    ApiErrorCode.timeout => 'error.timeout',
    ApiErrorCode.invalidMoney => 'error.invalidData',
    ApiErrorCode.invalidResponse => 'error.invalidData',
    _ => 'error.generic',
  };
}
