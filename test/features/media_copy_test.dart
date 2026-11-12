import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/l10n/app_localizations_ru.dart';

void main() {
  final l10n = AppLocalizationsRu();

  final platformSpecific = RegExp(
    r'iOS|iPhone|iPad|Android|App Store|Play Market|Google Фото',
    caseSensitive: false,
  );

  test('общие сообщения не ссылаются на одну платформу', () {
    final messages = <String, String>{
      'mediaHeicUnsupported': l10n.mediaHeicUnsupported,
      'mediaUnsupported': l10n.mediaUnsupported,
      'mediaUnreadable': l10n.mediaUnreadable,
      'mediaPermissionTitle': l10n.mediaPermissionTitle,
      'mediaPermissionBody': l10n.mediaPermissionBody,
      'mediaTooLarge': l10n.mediaTooLarge(10),
      'mediaTooSmallPixels': l10n.mediaTooSmallPixels(100, 100),
    };
    for (final entry in messages.entries) {
      expect(
        platformSpecific.hasMatch(entry.value),
        isFalse,
        reason: '${entry.key}: «${entry.value}»',
      );
    }
  });

  test('HEIC: совет выполним на обеих платформах', () {
    expect(l10n.mediaHeicUnsupported, contains('JPEG'));
    expect(l10n.mediaHeicUnsupported.toLowerCase(), contains('сохраните'));
  });

  test('доступ к фото: путь в настройки без iOS-стрелок', () {
    expect(l10n.mediaPermissionBody, isNot(contains('→')));
    expect(l10n.mediaPermissionBody.toLowerCase(), contains('настройк'));
  });
}
