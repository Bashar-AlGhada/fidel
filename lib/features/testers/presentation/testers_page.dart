import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/sampling/active_module.dart';
import '../../../application/sampling/sampling_provider.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_card.dart';

class TestersPage extends ConsumerWidget {
  const TestersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeModule = ref.watch(activeModuleProvider);
    if (activeModule != ActiveModule.testers) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(activeModuleProvider.notifier).setModule(ActiveModule.testers);
      });
    }

    final tokens = Theme.of(context).extension<ThemeTokensExtension>()!.tokens;

    return Scaffold(
      appBar: AppBar(title: Text('nav.testers'.tr)),
      body: ListView(
        padding: EdgeInsets.all(tokens.space2),
        children: const [
          _TesterTile(
            route: '/testers/screen',
            icon: Icons.smart_display_outlined,
            titleKey: 'testers.screenTester',
            subtitleKey: 'testers.screenTesterHint',
          ),
          _TesterTile(
            route: '/testers/noise',
            icon: Icons.graphic_eq_outlined,
            titleKey: 'testers.noiseChecker',
            subtitleKey: 'testers.noiseCheckerHint',
          ),
          _TesterTile(
            route: '/testers/battery',
            icon: Icons.battery_charging_full_outlined,
            titleKey: 'testers.batteryMonitor',
            subtitleKey: 'testers.batteryMonitorHint',
          ),
          _TesterTile(
            route: '/testers/network',
            icon: Icons.network_check_outlined,
            titleKey: 'testers.networkMonitor',
            subtitleKey: 'testers.networkMonitorHint',
          ),
          _TesterTile(
            route: '/testers/cpu',
            icon: Icons.developer_board_outlined,
            titleKey: 'testers.cpuMonitor',
            subtitleKey: 'testers.cpuMonitorHint',
          ),
        ],
      ),
    );
  }
}

class _TesterTile extends StatelessWidget {
  const _TesterTile({
    required this.route,
    required this.icon,
    required this.titleKey,
    required this.subtitleKey,
  });

  final String route;
  final IconData icon;
  final String titleKey;
  final String subtitleKey;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => context.go(route),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleKey.tr,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitleKey.tr,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
