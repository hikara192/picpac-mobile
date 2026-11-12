import 'package:api_contract/api_contract.dart';

import '../../l10n/app_localizations.dart';
import '../payment_controller.dart';
import '../payment_method.dart';
import '../../core/presentation/failure_text.dart';

String paymentMethodLabel(AppLocalizations l10n, PaymentMethod method) =>
    switch (method.titleKey) {
      'payment.method.card' => l10n.paymentMethodCard,
      'payment.method.sbp' => l10n.paymentMethodSbp,
      'payment.method.cod' => l10n.paymentMethodCod,
      'payment.method.wallet' => l10n.paymentMethodWallet,
      _ => l10n.paymentMethodUnknown,
    };

String? paymentMethodHint(AppLocalizations l10n, PaymentMethod method) =>
    switch (method.kind) {
      PaymentMethodKind.sbp => l10n.paymentSbpHint,
      PaymentMethodKind.cod => l10n.paymentOnDeliveryHint,
      _ => null,
    };

String paymentStatusLabel(AppLocalizations l10n, PaymentStatus? status) =>
    switch (status) {
      null || PaymentStatus.unknown => l10n.paymentStatusUnknown,
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
    };

String paymentFailureText(AppLocalizations l10n, Failure failure) =>
    switch (failure.code) {
      'payment_already_paid' => l10n.paymentAlreadyPaid,
      'payment_not_required' => l10n.paymentNotRequired,
      PaymentErrorCode.hostedPageFailed => l10n.paymentHostedPageFailed,
      PaymentErrorCode.methodUnavailable => l10n.paymentNoMethods,
      PaymentErrorCode.checkFailed => l10n.paymentCheckFailed,
      PaymentErrorCode.intentMissing => l10n.paymentCheckFailed,
      PaymentErrorCode.notPayable => l10n.paymentNotPayable,
      PaymentErrorCode.receiptUnavailable => l10n.paymentReceiptUnavailable,
      _ => failureText(l10n, failure),
    };
