import 'package:api_contract/api_contract.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../core/presentation/format.dart';
import '../../core/presentation/state_views.dart';
import '../../core/presentation/text_tones.dart';
import '../../core/presentation/a11y.dart';

class PaymentReceiptPage extends StatelessWidget {
  const PaymentReceiptPage({required this.receipt, super.key});

  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.paymentReceiptTitle)),
      body: ListView(
        padding: const EdgeInsets.all(PicPacSpacing.lg),
        children: <Widget>[
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _ReceiptRow(
                  label: l10n.paymentReceiptFiscal,
                  value: receipt.fiscalId,
                  monospace: true,
                ),
                const Divider(height: PicPacSpacing.xl),
                _ReceiptRow(
                  label: l10n.paymentReceiptAmount,
                  value: fmt.money(receipt.amount),
                  emphasized: true,
                ),
                const SizedBox(height: PicPacSpacing.sm),
                _ReceiptRow(
                  label: l10n.paymentReceiptDate,
                  value: fmt.dateTime(receipt.issuedAt),
                ),
                if (receipt.vat != null) ...<Widget>[
                  const SizedBox(height: PicPacSpacing.sm),
                  _ReceiptRow(
                    label: l10n.paymentReceiptVat,
                    value: fmt.money(receipt.vat!),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: PicPacSpacing.lg),
          MinTapTarget(
            child: FilledButton.icon(
              key: const Key('receipt-share'),
              onPressed: () => _share(context),
              icon: const Icon(Icons.ios_share, size: 18),
              label: Text(l10n.paymentReceiptShare),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final text = <String>[
      l10n.paymentReceiptTitle,
      '${l10n.paymentReceiptFiscal}: ${receipt.fiscalId}',
      '${l10n.paymentReceiptAmount}: ${fmt.money(receipt.amount)}',
      '${l10n.paymentReceiptDate}: ${fmt.dateTime(receipt.issuedAt)}',
    ].join('\n');
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: l10n.paymentReceiptSubject),
      );
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.paymentShareFailed)));
    }
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool emphasized;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = emphasized
        ? theme.textTheme.titleMedium?.copyWith(color: PicPacColors.accentText)
        : theme.textTheme.bodyMedium;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: FunnelText.secondary,
            ),
          ),
        ),
        const SizedBox(width: PicPacSpacing.md),
        Flexible(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: monospace
                  ? style?.copyWith(
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    )
                  : style,
            ),
          ),
        ),
      ],
    );
  }
}
