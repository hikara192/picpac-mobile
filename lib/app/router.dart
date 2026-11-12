import 'package:api_contract/api_contract.dart' hide TextAlign;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/session/session_controller.dart';
import '../core/session/session_view.dart';
import '../l10n/app_localizations.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/cart/presentation/cart_page.dart';
import '../features/catalog/presentation/catalog_page.dart';
import '../features/catalog/presentation/product_page.dart';
import '../features/checkout/presentation/checkout_page.dart';
import '../features/create/presentation/create_page.dart';
import '../features/create/presentation/projects_page.dart';
import '../features/editor/presentation/editor_page.dart';
import '../features/inspiration/presentation/inspiration_detail_page.dart';
import '../features/inspiration/presentation/inspiration_page.dart';
import '../features/orders/presentation/order_detail_page.dart';
import '../features/orders/presentation/orders_page.dart';
import '../features/preflight/presentation/preflight_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/support/presentation/support_page.dart';
import 'motion.dart';
import 'routes.dart';
import 'shell.dart';
import 'theme/tokens.dart';

export 'routes.dart';

final Provider<GoRouter> routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  var handledExpiry = ref.read(sessionControllerProvider).expiryCount;
  late final GoRouter router;
  ref.listen<SessionView>(sessionControllerProvider, (previous, next) {
    refresh.value++;
    if (next.expiryCount <= handledExpiry) return;
    handledExpiry = next.expiryCount;
    _openLoginAfterExpiry(router);
  });
  router = GoRouter(
    initialLocation: AppRoutes.catalog,
    debugLogDiagnostics: false,
    refreshListenable: refresh,
    redirect: (context, state) =>
        appRedirect(state, ref.read(sessionControllerProvider)),
    routes: <RouteBase>[
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.catalog,
            pageBuilder: (context, state) =>
                _screenPage(state, const CatalogPage()),
            routes: <RouteBase>[
              GoRoute(
                path: ':productId',
                pageBuilder: (context, state) => _screenPage(
                  state,
                  ProductPage(productId: state.pathParameters['productId']!),
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.inspiration,
            pageBuilder: (context, state) =>
                _screenPage(state, const InspirationPage()),
            routes: <RouteBase>[
              GoRoute(
                path: ':inspirationId',
                pageBuilder: (context, state) => _screenPage(
                  state,
                  InspirationDetailPage(
                    inspirationId: state.pathParameters['inspirationId']!,
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.orders,
            pageBuilder: (context, state) =>
                _screenPage(state, const OrdersPage()),
            routes: <RouteBase>[
              GoRoute(
                path: 'lookup',
                pageBuilder: (context, state) =>
                    _screenPage(state, const OrdersPage(lookupMode: true)),
              ),
              GoRoute(
                path: ':orderId',
                pageBuilder: (context, state) => _screenPage(
                  state,
                  OrderDetailPage(
                    orderId: state.pathParameters['orderId']!,
                    initialOrder: state.extra is Order
                        ? state.extra! as Order
                        : null,
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.support,
            pageBuilder: (context, state) =>
                _screenPage(state, const SupportPage()),
            routes: <RouteBase>[
              GoRoute(
                path: ':ticketId',
                pageBuilder: (context, state) => _screenPage(
                  state,
                  SupportPage(ticketId: state.pathParameters['ticketId']),
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (context, state) =>
                _screenPage(state, const ProfilePage()),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => _screenPage(
          state,
          LoginPage(
            next: AppRoutes.safeNext(state.uri.queryParameters['next']),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.create,
        pageBuilder: (context, state) => _screenPage(
          state,
          CreatePage(designId: state.pathParameters['designId']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.editor,
        pageBuilder: (context, state) => _screenPage(
          state,
          EditorPage(
            designId: state.pathParameters['designId']!,
            focus: state.extra is EditorFocus
                ? state.extra! as EditorFocus
                : null,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.preflight,
        pageBuilder: (context, state) => _screenPage(
          state,
          PreflightPage(designId: state.pathParameters['designId']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.cart,
        pageBuilder: (context, state) => _screenPage(state, const CartPage()),
      ),
      GoRoute(
        path: AppRoutes.projects,
        pageBuilder: (context, state) =>
            _screenPage(state, const ProjectsPage()),
      ),
      GoRoute(
        path: AppRoutes.checkout,
        pageBuilder: (context, state) =>
            _screenPage(state, const CheckoutPage()),
      ),
    ],
    errorBuilder: (context, state) =>
        _RouteErrorPage(path: state.uri.toString()),
  );
  return router;
});

CustomTransitionPage<void> _screenPage(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: Motion.screen,
      reverseTransitionDuration: Motion.screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (reducedMotion(context)) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: Motion.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: AnimatedBuilder(
            animation: curved,
            builder: (context, child) => Transform.translate(
              offset: Offset(8 * (1 - curved.value), 0),
              child: child,
            ),
            child: child,
          ),
        );
      },
    );

void _openLoginAfterExpiry(GoRouter router) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final location = router.routerDelegate.currentConfiguration.uri.toString();
    if (location == AppRoutes.login ||
        location.startsWith('${AppRoutes.login}?')) {
      return;
    }
    final path = Uri.parse(location).path;
    if (!AppRoutes.requiresAccount(path)) return;
    router.go(AppRoutes.loginFor(location));
  });
  WidgetsBinding.instance.scheduleFrame();
}

class _RouteErrorPage extends StatelessWidget {
  const _RouteErrorPage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(PicPacSpacing.xl),
          child: Text(
            l10n.routeNotFound(path),
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

@visibleForTesting
String? appRedirect(GoRouterState state, SessionView session) {
  final path = state.uri.path;
  if (path == AppRoutes.login) {
    return null;
  }
  if (session.isSupportAgent) {
    final isSupport =
        path == AppRoutes.support || path.startsWith('${AppRoutes.support}/');
    final isOrder =
        path == AppRoutes.orders || path.startsWith('${AppRoutes.orders}/');
    if (!isSupport && !isOrder && path != AppRoutes.profile) {
      return AppRoutes.support;
    }
    return null;
  }
  final lookedUpOrder =
      path.startsWith('${AppRoutes.orders}/') && state.extra is Order;
  if (lookedUpOrder) return null;
  final needsLogin =
      (AppRoutes.requiresAccount(path) && !session.isAccount) ||
      (AppRoutes.requiresSession(path) && !session.hasSession);
  if (needsLogin) return AppRoutes.loginFor(state.uri.toString());
  return null;
}
