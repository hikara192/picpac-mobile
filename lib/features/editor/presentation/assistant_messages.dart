import 'package:api_contract/api_contract.dart';
import 'package:intl/intl.dart';

import '../../../ai/ai_port.dart';
import '../../../l10n/app_localizations.dart';

String editPlanEntryText(AppLocalizations l10n, EditPlanEntry entry) {
  final details = _details(l10n, entry);
  return switch (entry.messageKey) {
    'aiChangeTone' => l10n.assistantChangeTone(details),
    'aiChangeLook' => l10n.assistantChangeLook(details),
    'aiChangeFraming' => l10n.assistantChangeFraming(details),
    'aiChangeAssignPhoto' => l10n.assistantChangeAssign(details),
    'aiChangeReplacePhoto' => l10n.assistantChangeReplace(details),
    'aiChangeClearSlot' => l10n.assistantChangeClearSlot(details),
    'aiChangeBackground' => l10n.assistantChangeBackground(details),
    'aiChangeLayout' => l10n.assistantChangeLayout(details),
    'aiChangeSwap' => l10n.assistantChangeSwap(details),
    _ => l10n.assistantChangeTone(details),
  };
}

String? editPlanEntryHint(AppLocalizations l10n, EditPlanEntry entry) {
  final labelKey = entry.args['labelKey'];
  if (labelKey is! String) return null;
  final label = adjustmentLabel(l10n, labelKey);
  return label.isEmpty ? null : label;
}

String adjustmentLabel(AppLocalizations l10n, String labelKey) =>
    switch (labelKey) {
      'editorToolLight' => l10n.editorToolLight,
      'editorToolWarmth' => l10n.editorToolWarmth,
      'editorAdjustContrast' => l10n.editorAdjustContrast,
      'editorAdjustTint' => l10n.editorAdjustTint,
      'editorAdjustSaturation' => l10n.editorAdjustSaturation,
      'editorAdjustVibrance' => l10n.editorAdjustVibrance,
      _ => l10n.assistantAdjustOther,
    };

String lookLabel(AppLocalizations l10n, String nameKey) => switch (nameKey) {
  'lookAsIs' => l10n.lookAsIs,
  'lookWarm' => l10n.lookWarm,
  'lookFilm' => l10n.lookFilm,
  'lookBright' => l10n.lookBright,
  'lookSoft' => l10n.lookSoft,
  'lookMono' => l10n.lookMono,
  _ => nameKey,
};

String aiModeText(AppLocalizations l10n, AiMode mode) => switch (mode) {
  AiMode.quick => l10n.assistantQuickMode,
  AiMode.remote => l10n.assistantRemoteMode,
};

String assistantFailureText(AppLocalizations l10n, Failure failure) {
  if (failure is PatchRejected) {
    return switch (failure.reason) {
      PatchErrorCode.revisionMismatch => l10n.assistantRejected,
      PatchErrorCode.unknownOperation ||
      PatchErrorCode.invalidOperation ||
      PatchErrorCode.unsupportedSchema ||
      PatchErrorCode.unsupportedBackground ||
      PatchErrorCode.unknownLook ||
      PatchErrorCode.unknownTemplate ||
      PatchErrorCode.commandRejected ||
      PatchErrorCode.spreadNotFound ||
      PatchErrorCode.slotNotFound ||
      PatchErrorCode.photoNotFound => l10n.assistantRejected,
      PatchErrorCode.noEffect ||
      PatchErrorCode.emptyPatch => l10n.assistantNoChange,
      PatchErrorCode.tooManyOperations ||
      PatchErrorCode.sessionNotReady => l10n.errorGeneric,
    };
  }
  return switch (failure.code) {
    ApiErrorCode.aiDisabled => l10n.assistantDisabled,
    ApiErrorCode.aiNoProposal => l10n.assistantNoChange,
    ApiErrorCode.networkUnavailable ||
    ApiErrorCode.timeout => l10n.assistantOffline,
    ApiErrorCode.rateLimited => l10n.errorRateLimited,
    ApiErrorCode.unauthorized ||
    ApiErrorCode.forbidden => l10n.errorUnauthorized,
    _ => l10n.errorGeneric,
  };
}

bool assistantCanRetry(Failure failure) {
  if (failure is PatchRejected) {
    return failure.reason != PatchErrorCode.sessionNotReady;
  }
  return failure.code != ApiErrorCode.aiDisabled &&
      failure.code != ApiErrorCode.aiNoProposal;
}

String _details(AppLocalizations l10n, EditPlanEntry entry) {
  final count = entry.args['count'];
  final countText = count is int ? '$count' : '';
  switch (entry.code) {
    case 'tone':
      final labelKey = entry.args['labelKey'];
      final field = labelKey is String ? adjustmentLabel(l10n, labelKey) : '';
      final value = _signed(l10n, entry.args['value']);
      return _join(<String>[
        field,
        if (countText.isNotEmpty) l10n.assistantPhotoCount(count as int),
        value,
      ]);
    case 'look':
      final nameKey = entry.args['nameKey'];
      final name = nameKey is String ? lookLabel(l10n, nameKey) : '';
      final strength = entry.args['strength'];
      final amount = strength is double && strength < 1
          ? NumberFormat.percentPattern(l10n.localeName).format(strength)
          : '';
      return _join(<String>[
        name,
        if (countText.isNotEmpty) l10n.assistantPhotoCount(count as int),
        if (amount.isNotEmpty) amount,
      ]);
    case 'framing':
      return count is int ? l10n.assistantSlotCount(count) : countText;
    case 'assign':
    case 'replace':
    case 'swap':
      return count is int ? l10n.assistantSlotCount(count) : countText;
    case 'clearSlot':
      return count is int ? l10n.assistantSlotCount(count) : countText;
    case 'background':
    case 'layout':
      return count is int ? l10n.assistantSheetCount(count) : countText;
    default:
      return countText;
  }
}

String _join(List<String> parts) =>
    parts.where((part) => part.isNotEmpty).join(', ');

String _signed(AppLocalizations l10n, Object? raw) {
  final value = switch (raw) {
    final double real => real,
    final int integer => integer.toDouble(),
    _ => null,
  };
  if (value == null) return '';
  final format = NumberFormat('0.##', l10n.localeName);
  final text = format.format(value.abs());
  if (value == 0) return text;
  return value > 0 ? '+$text' : '−$text';
}
