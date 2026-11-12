import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../app/theme/tokens.dart';
import '../../l10n/app_localizations.dart';

class MinTapTarget extends StatelessWidget {
  const MinTapTarget({required this.child, this.minWidth, super.key});

  final Widget child;

  final double? minWidth;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      minHeight: kMinTouchTarget,
      minWidth: minWidth ?? 0,
    ),
    child: child,
  );
}

class FocusRing extends StatefulWidget {
  const FocusRing({
    required this.child,
    this.borderRadius = PicPacRadii.card,
    super.key,
  });

  final Widget child;

  final double borderRadius;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (value) {
        if (value != _focused) setState(() => _focused = value);
      },
      child: Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          widget.child,
          if (_focused)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    border: Border.all(color: PicPacColors.ink, width: 2),
                    boxShadow: PicPacShadows.focus,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void announceToScreenReader(BuildContext context, String message) {
  if (message.isEmpty) return;
  SemanticsService.sendAnnouncement(
    View.of(context),
    message,
    TextDirection.ltr,
  );
}

String sliderSemanticValue(AppLocalizations l10n, String label, String value) =>
    l10n.a11ySliderValue(label, value);

String a11yProductCardLabel(
  AppLocalizations l10n, {
  required String title,
  required String price,
}) => l10n.a11yProductCard(price, title);

String a11yCartLineLabel(
  AppLocalizations l10n, {
  required String title,
  required String quantity,
}) => l10n.a11yCartLine(quantity, title);

String a11yTicketCardLabel(
  AppLocalizations l10n, {
  required String subject,
  required String status,
}) => l10n.a11yTicketCard(status, subject);

String a11yOrderCardLabel(
  AppLocalizations l10n, {
  required String number,
  required String status,
  required String total,
}) => l10n.a11yOrderCard(number, status, total);
