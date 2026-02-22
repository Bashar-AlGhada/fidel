import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/sampling/active_module.dart';
import '../../../application/sampling/sampling_provider.dart';

class SectionPlaceholderPage extends ConsumerWidget {
  const SectionPlaceholderPage({required this.titleKey, super.key});

  final String titleKey;

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
      appBar: AppBar(title: Text(titleKey.tr)),
      body: const Center(child: Text('Coming soon')),
    );
  }
}
