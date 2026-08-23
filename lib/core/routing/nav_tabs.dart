import 'package:flutter/material.dart';

/// Single source of truth for the root navigation tabs: order defines the
/// tab index; [path] drives both route matching and navigation.
class NavTabSpec {
  const NavTabSpec({
    required this.path,
    required this.icon,
    required this.selectedIcon,
    required this.labelKey,
  });

  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String labelKey;
}

const navTabs = <NavTabSpec>[
  NavTabSpec(
    path: '/',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    labelKey: 'nav.dashboard',
  ),
  NavTabSpec(
    path: '/info',
    icon: Icons.info_outline,
    selectedIcon: Icons.info,
    labelKey: 'nav.info',
  ),
  NavTabSpec(
    path: '/testers',
    icon: Icons.science_outlined,
    selectedIcon: Icons.science,
    labelKey: 'nav.testers',
  ),
  NavTabSpec(
    path: '/settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    labelKey: 'nav.settings',
  ),
];

/// Resolves a go_router location to its tab index. Unknown locations fall
/// back to the dashboard tab.
int tabIndexForLocation(String location) {
  for (var i = 0; i < navTabs.length; i++) {
    final path = navTabs[i].path;
    if (location == path || (path != '/' && location.startsWith(path))) {
      return i;
    }
  }
  return 0;
}
