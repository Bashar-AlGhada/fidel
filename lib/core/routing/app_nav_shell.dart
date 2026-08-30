import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/theme_tokens.dart';
import '../ui/glass_bottom_navigation.dart';
import '../ui/glass_card.dart';
import '../ui/layout.dart';
import 'nav_tabs.dart';

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
        final tokens = context.tokens;
        // Wide implies compact; one check covers both tiers.
        if (maxWidth >= kCompactBreakpoint) {
          final isWide = maxWidth >= kExtendedBreakpoint;
          return Scaffold(
            body: Row(
              children: [
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(tokens.grid * 1.5),
                    child: GlassCard(
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.grid * 0.75,
                        vertical: tokens.space1,
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
