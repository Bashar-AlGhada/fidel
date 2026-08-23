import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ui/glass_bottom_navigation.dart';
import '../ui/glass_card.dart';
import 'nav_tabs.dart';

const double _mediumBreakpoint = 700;
const double _wideBreakpoint = 1000;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        // Wide implies medium; one check covers both tiers.
        if (maxWidth >= _mediumBreakpoint) {
          final isWide = maxWidth >= _wideBreakpoint;
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
                          for (final tab in navTabs)
                            NavigationRailDestination(
                              icon: Icon(tab.icon),
                              selectedIcon: Icon(tab.selectedIcon),
                              label: Text(tab.labelKey.tr),
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
              for (final tab in navTabs)
                NavigationDestination(
                  icon: Icon(tab.icon),
                  selectedIcon: Icon(tab.selectedIcon),
                  label: tab.labelKey.tr,
                ),
            ],
          ),
        );
      },
    );
  }
}
