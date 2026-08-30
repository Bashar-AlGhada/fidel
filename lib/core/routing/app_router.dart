import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/sections/presentation/sensor_detail_page.dart';
import '../../features/sections/presentation/sensors_section_page.dart';
import '../../features/sections/presentation/sections_page.dart';
import '../../features/sections/sections_registry.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/testers/presentation/battery_monitor_page.dart';
import '../../features/testers/presentation/compass_page.dart';
import '../../features/testers/presentation/gps_page.dart';
import '../../features/testers/presentation/cpu_monitor_page.dart';
import '../../features/testers/presentation/network_monitor_page.dart';
import '../../features/testers/presentation/noise_checker_page.dart';
import '../../features/testers/presentation/screen_tester_page.dart';
import '../../features/testers/presentation/speed_test_page.dart';
import '../../features/testers/presentation/testers_page.dart';
import '../../features/testers/presentation/torch_tester_page.dart';
import '../../features/testers/presentation/vibration_tester_page.dart';
import '../ui/app_states.dart';
import 'app_nav_shell.dart';
import 'nav_tabs.dart';
import 'page_transitions.dart';

GoRouter buildRouter() {
  return GoRouter(
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: Text('error.pageTitle'.tr)),
      body: AppErrorState(
        title: 'error.pageNotFound'.tr,
        message: state.uri.toString(),
        actionLabel: 'action.retry'.tr,
        onAction: () => context.go('/'),
      ),
    ),
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          final index = tabIndexForLocation(state.uri.toString());
          return AppNavShell(
            currentIndex: index,
            onTap: (i) => context.go(navTabs[i].path),
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
                        pageBuilder: (c, s) => buildSlideUpTransition(
                          context: c,
                          state: s,
                          child: SensorDetailPage(
                            sensorKey: Uri.decodeComponent(
                              s.pathParameters['sensorKey'] ?? '',
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  GoRoute(
                    path: def.pathSegment,
                    builder: (c, s) => def.buildPage(),
                  ),
            ],
          ),
          GoRoute(
            path: '/testers',
            builder: (c, s) => const TestersPage(),
            routes: [
              GoRoute(
                path: 'screen',
                pageBuilder: (c, s) => buildFadeScaleTransition(
                  context: c,
                  state: s,
                  child: const ScreenTesterPage(),
                ),
              ),
              GoRoute(
                path: 'noise',
                pageBuilder: (c, s) => buildFadeScaleTransition(
                  context: c,
                  state: s,
                  child: const NoiseCheckerPage(),
                ),
              ),
              GoRoute(
                path: 'compass',
                pageBuilder: (c, s) => buildFadeScaleTransition(
                  context: c,
                  state: s,
                  child: const CompassPage(),
                ),
              ),
              GoRoute(
                path: 'gps',
                pageBuilder: (c, s) => buildFadeScaleTransition(
                  context: c,
                  state: s,
                  child: const GpsPage(),
                ),
              ),
              GoRoute(
                path: 'battery',
                pageBuilder: (c, s) => buildFadeScaleTransition(
                  context: c,
                  state: s,
                  child: const BatteryMonitorPage(),
                ),
              ),
              GoRoute(
                path: 'network',
                pageBuilder: (c, s) => buildFadeScaleTransition(
                  context: c,
                  state: s,
                  child: const NetworkMonitorPage(),
                ),
              ),
              GoRoute(
                path: 'cpu',
                pageBuilder: (c, s) => buildFadeScaleTransition(
                  context: c,
                  state: s,
                  child: const CpuMonitorPage(),
                ),
              ),
              GoRoute(
                path: 'vibration',
                pageBuilder: (c, s) => buildFadeScaleTransition(
                  context: c,
                  state: s,
                  child: const VibrationTesterPage(),
                ),
              ),
              GoRoute(
                path: 'torch',
                pageBuilder: (c, s) => buildFadeScaleTransition(
                  context: c,
                  state: s,
                  child: const TorchTesterPage(),
                ),
              ),
              GoRoute(
                path: 'speed',
                pageBuilder: (c, s) => buildFadeScaleTransition(
                  context: c,
                  state: s,
                  child: const SpeedTestPage(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
