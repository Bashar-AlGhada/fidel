import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/units_providers.dart';
import '../../../application/providers/system_providers.dart';
import '../../../application/sampling/active_module.dart';
import '../../../application/sampling/sampling_provider.dart';
import '../../../domain/units/unit_preferences.dart';

class MemoryPage extends ConsumerWidget {
  const MemoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeModule = ref.watch(activeModuleProvider);
    if (activeModule != ActiveModule.memory) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(activeModuleProvider.notifier).setModule(ActiveModule.memory);
      });
    }
    final mem = ref.watch(memoryStreamProvider);
    final prefs = ref
        .watch(unitPreferencesStreamProvider)
        .maybeWhen(data: (p) => p, orElse: () => UnitPreferences.defaults);
    final formatter = ref.watch(unitsFormatterProvider);

    return Scaffold(
      appBar: AppBar(title: Text('nav.memory'.tr)),
      body: mem.when(
        data: (m) {
          final usedPct = (m.usedRatio * 100).clamp(0, 100).toStringAsFixed(1);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '$usedPct%',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 12),
              RepaintBoundary(
                child: LinearProgressIndicator(value: m.usedRatio),
              ),
              const SizedBox(height: 12),
              Text(
                'memory.used'.trParams({
                  'value': formatter.formatBytes(
                    bytes: m.usedBytes,
                    base: prefs.dataSizeBase,
                  ),
                }),
              ),
              Text(
                'memory.available'.trParams({
                  'value': formatter.formatBytes(
                    bytes: m.availBytes,
                    base: prefs.dataSizeBase,
                  ),
                }),
              ),
              Text(
                'memory.total'.trParams({
                  'value': formatter.formatBytes(
                    bytes: m.totalBytes,
                    base: prefs.dataSizeBase,
                  ),
                }),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => const Center(child: Text('Unavailable')),
      ),
    );
  }
}
