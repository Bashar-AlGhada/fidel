import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/system_providers.dart';
import '../../../core/ui/app_states.dart';
import '../../../features/export/presentation/export_flow.dart';
import 'widgets/info_section.dart';

class SectionDetailPage extends ConsumerWidget {
  const SectionDetailPage({
    required this.sectionId,
    required this.fallbackTitleKey,
    super.key,
  });

  final String sectionId;
  final String fallbackTitleKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(sectionMetadataStreamProvider(sectionId));

    return Scaffold(
      appBar: AppBar(
        title: Text(fallbackTitleKey.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'action.export'.tr,
            onPressed: () =>
                exportSectionFlow(context, ref, section.asData?.value),
          ),
        ],
      ),
      body: section.when(
        skipLoadingOnReload: true,
        data: (value) {
          return RefreshIndicator(
            onRefresh: () => ref.read(getSectionMetadataProvider)(
              sectionId,
              forceRefresh: true,
            ),
            child: InfoSection(section: value),
          );
        },
        loading: () => const AppLoadingState(),
        error: (err, st) => AppErrorState(
          title: 'availability.unavailable'.tr,
          message: '$err',
          actionLabel: 'action.retry'.tr,
          onAction: () =>
              ref.invalidate(sectionMetadataStreamProvider(sectionId)),
        ),
      ),
    );
  }
}
