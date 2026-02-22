import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/system_providers.dart';
import '../../../application/sampling/active_module.dart';
import '../../../application/sampling/sampling_provider.dart';

class BatteryPage extends ConsumerWidget {
  const BatteryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeModule = ref.watch(activeModuleProvider);
    if (activeModule != ActiveModule.battery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(activeModuleProvider.notifier).setModule(ActiveModule.battery);
      });
    }
    final bat = ref.watch(batteryStreamProvider);

    return Scaffold(
      appBar: AppBar(title: Text('nav.battery'.tr)),
      body: bat.when(
        data: (b) {
          final pct = b.percent.clamp(0, 100);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('$pct%', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 12),
              RepaintBoundary(child: LinearProgressIndicator(value: pct / 100)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => const Center(child: Text('Unavailable')),
      ),
    );
  }
}
