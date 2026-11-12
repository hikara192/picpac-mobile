import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';

enum PaymentMethodKind {
  card('card'),


  sbp('sbp'),

  wallet('wallet'),

  cod('cod'),

  unknown('unknown');

  const PaymentMethodKind(this.wire);

  final String wire;

  static PaymentMethodKind fromWire(String? raw) {
    for (final kind in values) {
      if (kind != PaymentMethodKind.unknown && kind.wire == raw) return kind;
    }
    return PaymentMethodKind.unknown;
  }
}

final class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.kind,
    required this.titleKey,
    required this.currency,
    required this.region,
    required this.requiresHostedPage,
    this.provider,
    this.enabled = true,
    this.minAmountMinor,
    this.maxAmountMinor,
  });

  factory PaymentMethod.fromDto(PaymentMethodInfo info, {String? region}) =>
      PaymentMethod(
        id: info.id,
        kind: PaymentMethodKind.fromWire(info.kind),
        titleKey: info.titleKey,
        currency: info.currency,
        region: region ?? info.region ?? '',
        enabled: info.enabled,
        requiresHostedPage: info.requiresRedirect,
        minAmountMinor: info.minAmountMinor,
        maxAmountMinor: info.maxAmountMinor,
      );

  final String id;

  final PaymentMethodKind kind;

  final String titleKey;

  final String currency;

  final String region;

  final bool requiresHostedPage;

  final String? provider;

  final bool enabled;

  final int? minAmountMinor;

  final int? maxAmountMinor;

  bool get isOnDelivery => kind == PaymentMethodKind.cod;


  bool fitsAmount(int amountMinor) {
    final min = minAmountMinor;
    final max = maxAmountMinor;
    if (min != null && amountMinor < min) return false;
    if (max != null && amountMinor > max) return false;
    return true;
  }

  IconData get icon => switch (kind) {
    PaymentMethodKind.card => Icons.credit_card_outlined,
    PaymentMethodKind.sbp => Icons.qr_code_2,
    PaymentMethodKind.wallet => Icons.account_balance_wallet_outlined,
    PaymentMethodKind.cod => Icons.payments_outlined,
    PaymentMethodKind.unknown => Icons.payment,
  };
}
