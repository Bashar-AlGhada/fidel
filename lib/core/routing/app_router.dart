import 'package:go_router/go_router.dart';

import '../../features/battery/presentation/battery_page.dart';
import '../../features/cpu/presentation/cpu_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/memory/presentation/memory_page.dart';
import '../../features/sections/presentation/sensor_detail_page.dart';
import '../../features/sections/presentation/sensors_section_page.dart';
import '../../features/sections/presentation/sections_page.dart';
import '../../features/sections/sections_registry.dart';
import '../../features/settings/presentation/settings_page.dart';
import 'app_nav_shell.dart';

GoRouter buildRouter() {
  return GoRouter(
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          final location = state.uri.toString();
          final index = switch (location) {
            '/' => 0,
            String() when location.startsWith('/sections') => 1,
            '/memory' => 2,
            '/battery' => 3,
            '/cpu' => 4,
            '/settings' => 5,
            _ => 0,
          };

          return AppNavShell(
            currentIndex: index,
            onTap: (i) {
              switch (i) {
                case 0:
                  context.go('/');
                case 1:
                  context.go('/sections');
                case 2:
                  context.go('/memory');
                case 3:
                  context.go('/battery');
                case 4:
                  context.go('/cpu');
                case 5:
                  context.go('/settings');
              }
            },
            child: child,
          );
        },
        routes: [
          GoRoute(path: '/', builder: (c, s) => const DashboardPage()),
          GoRoute(path: '/memory', builder: (c, s) => const MemoryPage()),
          GoRoute(path: '/battery', builder: (c, s) => const BatteryPage()),
          GoRoute(path: '/cpu', builder: (c, s) => const CpuPage()),
          GoRoute(path: '/settings', builder: (c, s) => const SettingsPage()),
          GoRoute(
            path: '/sections',
            builder: (c, s) => const SectionsPage(),
            routes: [
              for (final def in sectionDefinitions)
                if (def.id == 'sensors')
                  GoRoute(
                    path: def.pathSegment,
                    builder: (c, s) => const SensorsSectionPage(),
                    routes: [
                      GoRoute(
                        path: ':sensorKey',
                        builder: (c, s) => SensorDetailPage(
                          sensorKey: Uri.decodeComponent(
                            s.pathParameters['sensorKey'] ?? '',
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  GoRoute(
                    path: def.pathSegment,
                    builder: (c, s) => buildSectionPage(def),
                  ),
            ],
          ),
        ],
      ),
    ],
  );
}
