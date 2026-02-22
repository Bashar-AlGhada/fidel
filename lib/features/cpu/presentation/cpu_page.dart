import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/system_providers.dart';
import '../../../application/sampling/active_module.dart';
import '../../../application/sampling/sampling_provider.dart';

class CpuPage extends ConsumerWidget {
  const CpuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeModule = ref.watch(activeModuleProvider);
    if (activeModule != ActiveModule.cpu) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(activeModuleProvider.notifier).setModule(ActiveModule.cpu);
      });
    }
    final cpu = ref.watch(cpuStreamProvider);

    return Scaffold(
      appBar: AppBar(title: Text('nav.cpu'.tr)),
      body: cpu.when(
        data: (v) {
          final percent = v.usage.toWholePercent();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '$percent%',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 12),
              RepaintBoundary(
                child: LinearProgressIndicator(value: v.usage.value),
              ),
              const SizedBox(height: 12),
              Text('Cores: ${v.cores}'),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => const Center(child: Text('Unavailable')),
      ),
    );
  }
}
