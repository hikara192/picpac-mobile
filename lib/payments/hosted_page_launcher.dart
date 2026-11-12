import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

enum HostedPageLaunch {
  launched,

  failed,
}

abstract interface class HostedPageLauncher {
  Future<HostedPageLaunch> open(Uri url);
}

final class SystemBrowserLauncher implements HostedPageLauncher {
  const SystemBrowserLauncher();

  @override
  Future<HostedPageLaunch> open(Uri url) async {
    if (!_isAllowed(url)) return HostedPageLaunch.failed;
    try {
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      return opened ? HostedPageLaunch.launched : HostedPageLaunch.failed;
    } on Object {
      return HostedPageLaunch.failed;
    }
  }

  static bool _isAllowed(Uri url) {
    if (!url.hasScheme || url.host.isEmpty) return false;
    if (url.scheme != 'https' && url.scheme != 'http') return false;
    if (url.userInfo.isNotEmpty) return false;
    return true;
  }
}

final Provider<HostedPageLauncher> hostedPageLauncherProvider =
    Provider<HostedPageLauncher>((ref) => const SystemBrowserLauncher());
