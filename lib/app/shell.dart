import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme/tokens.dart';
import '../core/session/session_controller.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  static const List<_Tab> _customerTabs = <_Tab>[
    _Tab(AppRoutes.catalog, 'navCatalog', Icons.grid_view_outlined),
    _Tab(AppRoutes.inspiration, 'navIdeas', Icons.explore_outlined),
    _Tab(AppRoutes.orders, 'navOrders', Icons.receipt_long_outlined),
    _Tab(AppRoutes.profile, 'navProfile', Icons.person_outline),
  ];

  static const List<_Tab> _guestTabs = <_Tab>[
    _Tab(AppRoutes.catalog, 'navCatalog', Icons.grid_view_outlined),
    _Tab(AppRoutes.inspiration, 'navIdeas', Icons.explore_outlined),
  ];

  static const List<_Tab> _supportTabs = <_Tab>[
    _Tab(AppRoutes.support, 'navSupport', Icons.support_agent_outlined),
    _Tab(AppRoutes.profile, 'navProfile', Icons.person_outline),
  ];

  int _indexFor(List<_Tab> tabs) {
    for (var i = tabs.length - 1; i >= 0; i--) {
      if (location.startsWith(tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionControllerProvider);
    final supportMode = session.isSupportAgent;
    final guest = !session.isAccount;
    final tabs = supportMode
        ? _supportTabs
        : guest
        ? _guestTabs
        : _customerTabs;
    return Scaffold(
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: PicPacColors.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (guest)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  PicPacSpacing.lg,
                  PicPacSpacing.md,
                  PicPacSpacing.lg,
                  0,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('shell-login'),
                    onPressed: () => context.push(AppRoutes.loginFor(location)),
                    child: Text(l10n.actionLogin),
                  ),
                ),
              ),
            NavigationBar(
              selectedIndex: _indexFor(tabs),
              onDestinationSelected: (index) {
                final target = tabs[index].path;
                if (location != target) context.go(target);
              },
              destinations: <Widget>[
                for (final tab in tabs)
                  NavigationDestination(
                    icon: Icon(tab.icon),
                    label: switch (tab.labelKey) {
                      'navOrders' => l10n.navOrders,
                      'navSupport' => l10n.navSupport,
                      'navProfile' => l10n.navProfile,
                      'navIdeas' => l10n.navIdeas,
                      _ => l10n.navCatalog,
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab(this.path, this.labelKey, this.icon);

  final String path;
  final String labelKey;
  final IconData icon;
}
