import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/export_providers.dart';
import '../../../domain/export/export_format.dart';
import '../../../domain/entities/info/info_section_entity.dart';
import 'export_format_sheet.dart';

/// Shows the format sheet and runs [action] once a format is picked.
Future<void> runExportFlow(
  BuildContext context,
  Future<void> Function(ExportFormat format) action,
) async {
  final format = await showExportFormatSheet(context);
  if (format == null) return;
  if (!context.mounted) return;

  // Snapshot exports can compose many platform calls; keep the user
  // informed and surface failures instead of a silent void.
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    await action(format);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('availability.unavailable'.tr)));
    }
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

/// Shared export orchestration for metadata section pages: unavailable
/// guard, format sheet, section export, then system share sheet.
Future<void> exportSectionFlow(
  BuildContext context,
  WidgetRef ref,
  InfoSectionEntity? maybeSection,
) async {
  if (maybeSection == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('availability.unavailable'.tr)));
    return;
  }

  final service = ref.read(exportServiceProvider);
  await runExportFlow(context, (format) async {
    final file = await service.exportSection(
      maybeSection,
      format: format,
      fileBaseName: 'fidel-${maybeSection.id}',
    );
    await service.share(file);
  });
}
