import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/system_providers.dart';
import '../../../application/sampling/active_module.dart';
import '../../../application/sampling/sampling_provider.dart';
import '../sections_registry.dart';

class SectionsPage extends ConsumerWidget {
  const SectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeModule = ref.watch(activeModuleProvider);
    if (activeModule != ActiveModule.dashboard) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(activeModuleProvider.notifier)
            .setModule(ActiveModule.dashboard);
      });
    }

    return Scaffold(
      appBar: AppBar(title: Text('nav.sections'.tr)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sectionDefinitions.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final section = sectionDefinitions[index];
          final meta = ref.watch(sectionMetadataStreamProvider(section.id));

          return Card(
            child: ListTile(
              leading: Icon(section.icon),
              title: Text(section.titleKey.tr),
              subtitle: meta.when(
                data: (v) => Text('availability.${v.availability.name}'.tr),
                loading: () => Text('availability.loading'.tr),
                error: (err, st) => Text('availability.unavailable'.tr),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/sections/${section.pathSegment}'),
            ),
          );
        },
      ),
    );
  }
}
