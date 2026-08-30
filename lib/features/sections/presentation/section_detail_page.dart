import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/system_providers.dart';
import '../../../core/ui/app_page_scaffold.dart';
import '../../../core/ui/async_value_view.dart';
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

    // Wrapping the scaffold lets the indicator observe the page's inner
    // scrollable while keeping AppPageScaffold's padding contract.
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(getSectionMetadataProvider)(sectionId, forceRefresh: true),
      child: AppPageScaffold(
        title: fallbackTitleKey.tr,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'action.export'.tr,
            onPressed: () =>
                exportSectionFlow(context, ref, section.asData?.value),
          ),
        ],
        children: [
          AsyncValueView(
            value: section,
            data: (value) => InfoSection(section: value),
            loadingMessage: 'availability.loading'.tr,
            errorTitle: 'availability.unavailable'.tr,
            retryLabel: 'action.retry'.tr,
            onRetry: () =>
                ref.invalidate(sectionMetadataStreamProvider(sectionId)),
          ),
        ],
      ),
    );
  }
}
