import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/sections/presentation/sensor_detail_page.dart';
import '../../features/sections/presentation/sensors_section_page.dart';
import '../../features/sections/presentation/sections_page.dart';
import '../../features/sections/sections_registry.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/testers/presentation/battery_monitor_page.dart';
import '../../features/testers/presentation/cpu_monitor_page.dart';
import '../../features/testers/presentation/network_monitor_page.dart';
import '../../features/testers/presentation/noise_checker_page.dart';
import '../../features/testers/presentation/screen_tester_page.dart';
import '../../features/testers/presentation/testers_page.dart';
import 'app_nav_shell.dart';

GoRouter buildRouter() {
  return GoRouter(
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          final location = state.uri.toString();
          final index = switch (location) {
            '/' => 0,
            String() when location.startsWith('/info') => 1,
            String() when location.startsWith('/testers') => 2,
            '/settings' => 3,
            _ => 0,
          };

          return AppNavShell(
            currentIndex: index,
            onTap: (i) {
              switch (i) {
                case 0:
                  context.go('/');
                case 1:
                  context.go('/info');
                case 2:
                  context.go('/testers');
                case 3:
                  context.go('/settings');
              }
            },
            child: child,
          );
        },
        routes: [
          GoRoute(path: '/', builder: (c, s) => const DashboardPage()),
          GoRoute(path: '/settings', builder: (c, s) => const SettingsPage()),
          GoRoute(
            path: '/info',
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
          GoRoute(
            path: '/testers',
            builder: (c, s) => const TestersPage(),
            routes: [
              GoRoute(
                path: 'screen',
                builder: (c, s) => const ScreenTesterPage(),
              ),
              GoRoute(
                path: 'noise',
                builder: (c, s) => const NoiseCheckerPage(),
              ),
              GoRoute(
                path: 'battery',
                builder: (c, s) => const BatteryMonitorPage(),
              ),
              GoRoute(
                path: 'network',
                builder: (c, s) => const NetworkMonitorPage(),
              ),
              GoRoute(path: 'cpu', builder: (c, s) => const CpuMonitorPage()),
            ],
          ),
        ],
      ),
    ],
  );
}
