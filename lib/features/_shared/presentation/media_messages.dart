import 'package:design_core/design_core.dart';

import '../../../core/media/photo_format.dart';
import '../../../l10n/app_localizations.dart';

String photoRejectionText(AppLocalizations l10n, PhotoRejection rejection) =>
    switch (rejection.code) {
      PhotoRejectionCode.heicUnsupported => l10n.mediaHeicUnsupported,
      PhotoRejectionCode.unsupportedFormat => l10n.mediaUnsupported,
      PhotoRejectionCode.tooLarge => l10n.mediaTooLarge(
        PhotoFormats.maxMegabytes,
      ),
      PhotoRejectionCode.tooSmall => l10n.mediaTooSmallPixels(
        _asInt(rejection.args['width']),
        _asInt(rejection.args['height']),
      ),
      PhotoRejectionCode.duplicate => l10n.mediaDuplicatesSkipped(1),
      PhotoRejectionCode.unreadable => l10n.mediaUnreadable,
    };

String pickerFailureText(AppLocalizations l10n, Failure failure) =>
    switch (failure.code) {
      MediaErrorCode.permissionDenied => l10n.mediaPermissionBody,
      _ => l10n.errorGeneric,
    };

int _asInt(Object? value) => value is int ? value : 0;
