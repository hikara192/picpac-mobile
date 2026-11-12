import 'package:api_contract/api_contract.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../core/presentation/state_views.dart';

String orderStatusLabel(AppLocalizations l10n, OrderStatus status) =>
    switch (status) {
      OrderStatus.draft => l10n.orderStatusDraft,
      OrderStatus.placed => l10n.orderStatusPlaced,
      OrderStatus.accepted => l10n.orderStatusAccepted,
      OrderStatus.moderation => l10n.orderStatusModeration,
      OrderStatus.production => l10n.orderStatusProduction,
      OrderStatus.ready => l10n.orderStatusReady,
      OrderStatus.readyForPickup => l10n.orderStatusReadyForPickup,
      OrderStatus.shipped => l10n.orderStatusShipped,
      OrderStatus.completed => l10n.orderStatusCompleted,
      OrderStatus.canceled => l10n.orderStatusCanceled,
      OrderStatus.returned => l10n.orderStatusReturned,
      OrderStatus.unknown => l10n.statusUpdating,
    };

ChipTone orderStatusTone(OrderStatus status) => switch (status) {
  OrderStatus.completed => ChipTone.success,
  OrderStatus.ready || OrderStatus.readyForPickup => ChipTone.success,
  OrderStatus.production || OrderStatus.shipped => ChipTone.progress,
  OrderStatus.accepted || OrderStatus.placed => ChipTone.progress,
  OrderStatus.moderation => ChipTone.warning,
  OrderStatus.canceled || OrderStatus.returned => ChipTone.danger,
  OrderStatus.draft => ChipTone.neutral,
  OrderStatus.unknown => ChipTone.warning,
};

String paymentStatusLabel(AppLocalizations l10n, PaymentStatus status) =>
    switch (status) {
      PaymentStatus.created => l10n.paymentStatusCreated,
      PaymentStatus.requiresAction => l10n.paymentStatusRequiresAction,
      PaymentStatus.pendingUser => l10n.paymentStatusPendingUser,
      PaymentStatus.processing => l10n.paymentStatusProcessing,
      PaymentStatus.succeeded => l10n.paymentStatusSucceeded,
      PaymentStatus.failed => l10n.paymentStatusFailed,
      PaymentStatus.expired => l10n.paymentStatusExpired,
      PaymentStatus.canceled => l10n.paymentStatusCanceled,
      PaymentStatus.refunded => l10n.paymentStatusRefunded,
      PaymentStatus.partiallyRefunded => l10n.paymentStatusPartiallyRefunded,
      PaymentStatus.pendingOnDelivery => l10n.paymentStatusPendingOnDelivery,
      PaymentStatus.unknown => l10n.statusUpdating,
    };

ChipTone paymentStatusTone(PaymentStatus status) => switch (status) {
  PaymentStatus.succeeded => ChipTone.success,
  PaymentStatus.refunded || PaymentStatus.partiallyRefunded => ChipTone.warning,
  PaymentStatus.processing => ChipTone.progress,
  PaymentStatus.failed ||
  PaymentStatus.expired ||
  PaymentStatus.canceled => ChipTone.danger,
  PaymentStatus.created ||
  PaymentStatus.requiresAction ||
  PaymentStatus.pendingUser ||
  PaymentStatus.pendingOnDelivery ||
  PaymentStatus.unknown => ChipTone.warning,
};
