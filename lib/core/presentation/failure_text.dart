import 'package:api_contract/api_contract.dart';

import '../analytics.dart';
import '../../l10n/app_localizations.dart';

String failureText(AppLocalizations l10n, Failure failure) =>
    textForKey(l10n, messageKeyForFailure(failure));

String textForKey(AppLocalizations l10n, String key) => switch (key) {
  'error.unauthorized' => l10n.errorUnauthorized,
  'error.forbidden' => l10n.errorForbidden,
  'error.conflictRevision' => l10n.errorConflictRevision,
  'error.idempotencyConflict' => l10n.errorIdempotencyConflict,
  'error.validation' => l10n.errorValidation,
  'error.notFound' => l10n.errorNotFound,
  'error.rateLimited' => l10n.errorRateLimited,
  'error.invalidData' => l10n.errorInvalidData,
  'error.network' => l10n.errorNetwork,
  'error.timeout' => l10n.errorTimeout,
  _ => l10n.errorGeneric,
};

bool isAuthFailure(Failure failure) =>
    failure.code == ApiErrorCode.unauthorized ||
    failure.code == ApiErrorCode.forbidden;

String priceLineLabel(AppLocalizations l10n, String labelKey) =>
    switch (labelKey) {
      'price.product' => l10n.priceProduct,
      'price.options' => l10n.priceOptions,
      'price.promo' => l10n.pricePromo,
      'price.delivery' => l10n.priceDelivery,
      _ => labelKey,
    };

String deliveryOptionLabel(AppLocalizations l10n, String titleKey) =>
    switch (titleKey) {
      'delivery.pickup' => l10n.deliveryPickup,
      'delivery.europochta' => l10n.deliveryEuropochta,
      'delivery.belpochta' => l10n.deliveryBelpochta,
      'delivery.ems' => l10n.deliveryEms,
      'delivery.courierMinsk' => l10n.deliveryCourierMinsk,
      'delivery.courierBelarus' => l10n.deliveryCourierBelarus,
      _ => l10n.deliveryKindUnknown,
    };

String deliveryKindLabel(AppLocalizations l10n, DeliveryKind kind) =>
    switch (kind) {
      DeliveryKind.pickup => l10n.deliveryKindPickup,
      DeliveryKind.post => l10n.deliveryKindPost,
      DeliveryKind.ems => l10n.deliveryKindEms,
      DeliveryKind.courier => l10n.deliveryKindCourier,
      DeliveryKind.unknown => l10n.deliveryKindUnknown,
    };
