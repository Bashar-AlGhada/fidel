import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/system_providers.dart';
import '../../../application/sampling/active_module.dart';
import '../../../application/sampling/sampling_provider.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_states.dart';

class CpuMonitorPage extends ConsumerWidget {
  const CpuMonitorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeModule = ref.watch(activeModuleProvider);
    if (activeModule != ActiveModule.testers) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(activeModuleProvider.notifier).setModule(ActiveModule.testers);
      });
    }

    final cpu = ref.watch(cpuStreamProvider);
    final tokens = Theme.of(context).extension<ThemeTokensExtension>()!.tokens;

    return Scaffold(
      appBar: AppBar(title: Text('testers.cpuMonitor'.tr)),
      body: cpu.when(
        data: (v) {
          final percent = v.usage.toWholePercent();
          return ListView(
            padding: EdgeInsets.all(tokens.space3),
            children: [
              Text(
                '$percent%',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              SizedBox(height: tokens.space3),
              LinearProgressIndicator(value: v.usage.value),
              SizedBox(height: tokens.space3),
              Text('cpu.cores'.trParams({'value': '${v.cores}'})),
            ],
          );
        },
        loading: () => const AppLoadingState(),
        error: (error, stack) => AppErrorState(
          title: 'availability.unavailable'.tr,
          actionLabel: 'action.retry'.tr,
          onAction: () => ref.invalidate(cpuStreamProvider),
        ),
      ),
    );
  }
}
