import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/system_providers.dart';
import '../../../application/sampling/active_module.dart';
import '../../../application/sampling/sampling_provider.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_states.dart';

class BatteryMonitorPage extends ConsumerWidget {
  const BatteryMonitorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeModule = ref.watch(activeModuleProvider);
    if (activeModule != ActiveModule.testers) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(activeModuleProvider.notifier).setModule(ActiveModule.testers);
      });
    }

    final battery = ref.watch(batteryStreamProvider);
    final tokens = Theme.of(context).extension<ThemeTokensExtension>()!.tokens;

    return Scaffold(
      appBar: AppBar(title: Text('testers.batteryMonitor'.tr)),
      body: battery.when(
        data: (b) {
          final pct = b.percent.clamp(0, 100);
          return ListView(
            padding: EdgeInsets.all(tokens.space3),
            children: [
              Text('$pct%', style: Theme.of(context).textTheme.displayMedium),
              SizedBox(height: tokens.space3),
              LinearProgressIndicator(value: pct / 100),
            ],
          );
        },
        loading: () => const AppLoadingState(),
        error: (error, stack) => AppErrorState(
          title: 'availability.unavailable'.tr,
          actionLabel: 'action.retry'.tr,
          onAction: () => ref.invalidate(batteryStreamProvider),
        ),
      ),
    );
  }
}
