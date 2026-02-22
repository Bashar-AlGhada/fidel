import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppNavShell extends StatefulWidget {
  const AppNavShell({required this.currentIndex, required this.onTap, required this.child, super.key});

  final int currentIndex;
  final ValueChanged<int> onTap;
  final Widget child;

  @override
  State<AppNavShell> createState() => _AppNavShellState();
}

class _AppNavShellState extends State<AppNavShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final isMedium = constraints.maxWidth >= 600;

        if (isWide || isMedium) {
          return AppNavShellScope(
            hasDrawer: false,
            openDrawer: null,
            child: Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    extended: isWide,
                    selectedIndex: widget.currentIndex,
                    onDestinationSelected: widget.onTap,
                    labelType: isWide ? NavigationRailLabelType.none : NavigationRailLabelType.selected,
                    destinations: [
                      NavigationRailDestination(
                        icon: const Icon(Icons.dashboard_outlined),
                        selectedIcon: const Icon(Icons.dashboard),
                        label: Text('nav.dashboard'.tr),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.view_list_outlined),
                        selectedIcon: const Icon(Icons.view_list),
                        label: Text('nav.sections'.tr),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.memory_outlined),
                        selectedIcon: const Icon(Icons.memory),
                        label: Text('nav.memory'.tr),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.battery_std_outlined),
                        selectedIcon: const Icon(Icons.battery_std),
                        label: Text('nav.battery'.tr),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.speed_outlined),
                        selectedIcon: const Icon(Icons.speed),
                        label: Text('nav.cpu'.tr),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.settings_outlined),
                        selectedIcon: const Icon(Icons.settings),
                        label: Text('nav.settings'.tr),
                      ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          );
        }

        return AppNavShellScope(
          hasDrawer: true,
          openDrawer: () => _scaffoldKey.currentState?.openDrawer(),
          child: Scaffold(
            key: _scaffoldKey,
            drawer: Drawer(
              child: SafeArea(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.dashboard_outlined),
                      title: Text('nav.dashboard'.tr),
                      selected: widget.currentIndex == 0,
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onTap(0);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.view_list_outlined),
                      title: Text('nav.sections'.tr),
                      selected: widget.currentIndex == 1,
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onTap(1);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.memory_outlined),
                      title: Text('nav.memory'.tr),
                      selected: widget.currentIndex == 2,
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onTap(2);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.battery_std_outlined),
                      title: Text('nav.battery'.tr),
                      selected: widget.currentIndex == 3,
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onTap(3);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.speed_outlined),
                      title: Text('nav.cpu'.tr),
                      selected: widget.currentIndex == 4,
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onTap(4);
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.settings_outlined),
                      title: Text('nav.settings'.tr),
                      selected: widget.currentIndex == 5,
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onTap(5);
                      },
                    ),
                  ],
                ),
              ),
            ),
            body: widget.child,
          ),
        );
      },
    );
  }
}

class AppNavShellScope extends InheritedWidget {
  const AppNavShellScope({required this.hasDrawer, required this.openDrawer, required super.child, super.key});

  final bool hasDrawer;
  final VoidCallback? openDrawer;

  static AppNavShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppNavShellScope>();
  }

  @override
  bool updateShouldNotify(covariant AppNavShellScope oldWidget) {
    return oldWidget.hasDrawer != hasDrawer || oldWidget.openDrawer != openDrawer;
  }
}
