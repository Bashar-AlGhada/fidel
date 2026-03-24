import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ui/glass_bottom_navigation.dart';
import '../ui/glass_card.dart';

class AppNavShell extends StatelessWidget {
  const AppNavShell({
    required this.currentIndex,
    required this.onTap,
    required this.child,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final destinations = <_NavDestination>[
      _NavDestination(
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: 'nav.dashboard'.tr,
      ),
      _NavDestination(
        icon: Icons.info_outline,
        selectedIcon: Icons.info,
        label: 'nav.info'.tr,
      ),
      _NavDestination(
        icon: Icons.science_outlined,
        selectedIcon: Icons.science,
        label: 'nav.testers'.tr,
      ),
      _NavDestination(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: 'nav.settings'.tr,
      ),
    ];

    return AppNavShellScope(
      hasDrawer: false,
      openDrawer: null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1000;
          final isMedium = constraints.maxWidth >= 700;
          if (isWide || isMedium) {
            return Scaffold(
              body: Row(
                children: [
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        child: NavigationRail(
                          extended: isWide,
                          selectedIndex: currentIndex,
                          onDestinationSelected: onTap,
                          labelType: isWide
                              ? NavigationRailLabelType.none
                              : NavigationRailLabelType.selected,
                          destinations: [
                            for (final destination in destinations)
                              NavigationRailDestination(
                                icon: Icon(destination.icon),
                                selectedIcon: Icon(destination.selectedIcon),
                                label: Text(destination.label),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: child),
                ],
              ),
            );
          }

          return Scaffold(
            body: child,
            bottomNavigationBar: GlassBottomNavigation(
              currentIndex: currentIndex,
              onTap: onTap,
              destinations: [
                for (final destination in destinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: destination.label,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class AppNavShellScope extends InheritedWidget {
  const AppNavShellScope({
    required this.hasDrawer,
    required this.openDrawer,
    required super.child,
    super.key,
  });

  final bool hasDrawer;
  final VoidCallback? openDrawer;

  static AppNavShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppNavShellScope>();
  }

  @override
  bool updateShouldNotify(covariant AppNavShellScope oldWidget) {
    return oldWidget.hasDrawer != hasDrawer ||
        oldWidget.openDrawer != openDrawer;
  }
}

class _NavDestination {
  const _NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
