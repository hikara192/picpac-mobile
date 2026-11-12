import 'package:design_core/design_core.dart';

import '../../../core/presentation/format.dart';
import '../../../l10n/app_localizations.dart';

String preflightIssueText(AppLocalizations l10n, PreflightIssue issue) =>
    switch (issue.code) {
      PreflightCode.emptySlot => l10n.preflightEmptySlot,
      PreflightCode.lowDpi => l10n.preflightLowDpi(
        _text(issue.args['photoPx'], '—'),
        _size(l10n, issue.args),
        _text(issue.args['requiredPx'], '—'),
      ),
      PreflightCode.unsupportedFormat => l10n.preflightUnsupported(
        _text(issue.args['mimeType'], '—'),
      ),
      PreflightCode.safeZone => l10n.preflightSafeZone(
        Fmt.millimetres(
          _number(issue.args['overflowMm']),
          locale: l10n.localeName,
        ),
      ),
      PreflightCode.textOverflow => l10n.preflightTextOverflow,
      PreflightCode.faceAtEdge => l10n.preflightFaceAtEdge,
    };

String? preflightIssueHint(
  AppLocalizations l10n,
  PreflightIssue issue,
  int sheetIndex,
) {
  if (issue.code != PreflightCode.emptySlot) return null;
  return l10n.preflightEmptySlotHint(
    sheetIndex + 1,
    issue.slotId ?? issue.targetId,
  );
}

String _size(AppLocalizations l10n, Map<String, Object?> args) {
  final width = _number(args['slotWidthMm']);
  final height = _number(args['slotHeightMm']);
  return l10n.productSize(
    Fmt.millimetres(width, locale: l10n.localeName),
    Fmt.millimetres(height, locale: l10n.localeName),
  );
}

String _text(Object? value, String fallback) =>
    value is String && value.isNotEmpty ? value : fallback;

double _number(Object? value) => switch (value) {
  final num number => number.toDouble(),
  final String text => double.tryParse(text) ?? 0,
  _ => 0,
};
