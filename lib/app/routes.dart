abstract final class AppRoutes {
  static const String catalog = '/catalog';
  static const String product = '/catalog/:productId';
  static const String inspiration = '/inspiration';
  static const String create = '/create/:designId';
  static const String editor = '/editor/:designId';
  static const String preflight = '/preflight/:designId';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String orders = '/orders';
  static const String order = '/orders/:orderId';
  static const String orderLookup = '/orders/lookup';
  static const String support = '/support';
  static const String ticket = '/support/:ticketId';
  static const String profile = '/profile';
  static const String projects = '/projects';
  static const String login = '/login';

  static String orderByNumber(String number) =>
      '$orderLookup?number=${Uri.encodeQueryComponent(number)}';

  static String productFor(String productId) => '$catalog/$productId';

  static String inspirationFor(String inspirationId) =>
      '$inspiration/$inspirationId';

  static String createFor(String designId) => '/create/$designId';

  static String editorFor(String designId) => '/editor/$designId';

  static String preflightFor(String designId) => '/preflight/$designId';

  static String orderFor(String orderId) => '$orders/$orderId';

  static String loginFor(String location) =>
      '$login?next=${Uri.encodeQueryComponent(location)}';

  static String? safeNext(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (!raw.startsWith('/') || raw.startsWith('//')) return null;
    return raw;
  }

  static bool requiresAccount(String path) {
    if (path == orderLookup) return false;
    return path == checkout || path == orders || path.startsWith('$orders/');
  }

  static bool requiresSession(String path) =>
      path == profile || path.startsWith('$profile/');
}

final class EditorFocus {
  const EditorFocus({required this.spreadId, required this.slotId});

  final String spreadId;

  final String slotId;
}
