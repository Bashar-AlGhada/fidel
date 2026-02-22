import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/system_providers.dart';
import '../../../application/providers/export_providers.dart';
import '../../../application/sampling/active_module.dart';
import '../../../application/sampling/sampling_provider.dart';
import '../../../domain/entities/info/info_section_entity.dart';
import '../../../features/export/presentation/export_format_sheet.dart';
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
    final activeModule = ref.watch(activeModuleProvider);
    if (activeModule != ActiveModule.sections) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(activeModuleProvider.notifier)
            .setModule(ActiveModule.sections);
      });
    }

    final section = ref.watch(sectionMetadataStreamProvider(sectionId));

    return Scaffold(
      appBar: AppBar(
        title: Text(fallbackTitleKey.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () => _export(context, ref, section.asData?.value),
          ),
        ],
      ),
      body: section.when(
        data: (value) {
          return RefreshIndicator(
            onRefresh: () => ref.read(getSectionMetadataProvider)(
              sectionId,
              forceRefresh: true,
            ),
            child: InfoSection(section: value),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => const Center(child: Text('Unavailable')),
      ),
    );
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    InfoSectionEntity? section,
  ) async {
    if (section == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('availability.unavailable'.tr)));
      return;
    }

    final format = await showExportFormatSheet(context);
    if (format == null) return;

    final service = ref.read(exportServiceProvider);
    final file = await service.exportSection(
      section,
      format: format,
      fileBaseName: 'fidel-${section.id}',
    );
    await service.share(file);
  }
}
