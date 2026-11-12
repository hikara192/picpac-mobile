import 'package:api_contract/api_contract.dart';

import '../../l10n/app_localizations.dart';

abstract final class ExportErrorCode {
  static const String documentUnavailable = 'export_document_unavailable';

  static const String nothingToExport = 'export_nothing_to_export';

  static const String renderFailed = 'export_render_failed';

  static const String shareFailed = 'export_share_failed';
}

String exportFailureText(AppLocalizations l10n, Failure failure) =>
    switch (failure.code) {
      ExportErrorCode.documentUnavailable => l10n.preflightShareNotLoaded,
      ExportErrorCode.nothingToExport => l10n.preflightShareNothing,
      ExportErrorCode.shareFailed => l10n.preflightShareOpenFailed,
      _ => l10n.preflightShareRenderFailed,
    };
