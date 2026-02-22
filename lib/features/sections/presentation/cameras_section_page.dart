import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/export_providers.dart';
import '../../../application/providers/system_providers.dart';
import '../../../application/sampling/active_module.dart';
import '../../../application/sampling/sampling_provider.dart';
import '../../../domain/entities/info/info_item_entity.dart';
import '../../../domain/entities/info/info_section_entity.dart';
import '../../../features/export/presentation/export_format_sheet.dart';

enum CameraFacingFilter { all, front, back, external }

class CamerasSectionPage extends ConsumerStatefulWidget {
  const CamerasSectionPage({super.key});

  @override
  ConsumerState<CamerasSectionPage> createState() => _CamerasSectionPageState();
}

class _CamerasSectionPageState extends ConsumerState<CamerasSectionPage> {
  String _query = '';
  CameraFacingFilter _filter = CameraFacingFilter.all;

  @override
  Widget build(BuildContext context) {
    final activeModule = ref.watch(activeModuleProvider);
    if (activeModule != ActiveModule.sections) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(activeModuleProvider.notifier)
            .setModule(ActiveModule.sections);
      });
    }

    final section = ref.watch(sectionMetadataStreamProvider('cameras'));

    return Scaffold(
      appBar: AppBar(
        title: Text('section.cameras'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () => _export(context, section.asData?.value),
          ),
        ],
      ),
      body: section.when(
        data: (value) => _buildLoaded(context, value),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => const Center(child: Text('Unavailable')),
      ),
    );
  }

  Future<void> _export(BuildContext context, InfoSectionEntity? section) async {
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

  Widget _buildLoaded(BuildContext context, InfoSectionEntity section) {
    final cameras = _extractCameras(section);
    final filtered = cameras
        .where((camera) {
          final facing = _cameraFacing(camera);
          if (_filter != CameraFacingFilter.all && facing != _filter) {
            return false;
          }
          if (_query.trim().isEmpty) return true;
          final q = _query.trim().toLowerCase();
          return _searchable(camera).contains(q);
        })
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(getSectionMetadataProvider)('cameras', forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'search.hintCameras'.tr,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                selected: _filter == CameraFacingFilter.all,
                label: 'filter.all'.tr,
                onTap: () => setState(() => _filter = CameraFacingFilter.all),
              ),
              _FilterChip(
                selected: _filter == CameraFacingFilter.front,
                label: 'filter.front'.tr,
                onTap: () => setState(() => _filter = CameraFacingFilter.front),
              ),
              _FilterChip(
                selected: _filter == CameraFacingFilter.back,
                label: 'filter.back'.tr,
                onTap: () => setState(() => _filter = CameraFacingFilter.back),
              ),
              _FilterChip(
                selected: _filter == CameraFacingFilter.external,
                label: 'filter.external'.tr,
                onTap: () =>
                    setState(() => _filter = CameraFacingFilter.external),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('search.noResults'.tr),
              ),
            )
          else
            ...filtered.map((camera) => _CameraCard(camera: camera)),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _extractCameras(InfoSectionEntity section) {
    final item = section.items.cast<InfoItemEntity?>().firstWhere(
      (it) => it?.labelKey == 'cameras.cameras',
      orElse: () => null,
    );
    final raw = item?.value?.text;
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList(growable: false);
      }
      if (decoded is Map) {
        return [decoded.cast<String, dynamic>()];
      }
    } catch (_) {}
    return const [];
  }

  CameraFacingFilter _cameraFacing(Map<String, dynamic> camera) {
    final raw =
        (camera['lensFacing'] ??
                camera['facing'] ??
                camera['lens_facing'] ??
                camera['lensFacingString'])
            ?.toString()
            .toLowerCase();
    if (raw == null) return CameraFacingFilter.external;
    if (raw.contains('front')) return CameraFacingFilter.front;
    if (raw.contains('back') || raw.contains('rear')) {
      return CameraFacingFilter.back;
    }
    return CameraFacingFilter.external;
  }

  String _searchable(Map<String, dynamic> camera) {
    final encoder = const JsonEncoder.withIndent(' ');
    return encoder.convert(camera).toLowerCase();
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Chip(
        label: Text(label),
        backgroundColor: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
      ),
    );
  }
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({required this.camera});

  final Map<String, dynamic> camera;

  @override
  Widget build(BuildContext context) {
    final encoder = const JsonEncoder.withIndent('  ');
    final id = (camera['cameraId'] ?? camera['id'] ?? camera['name'])
        ?.toString();
    final title = id == null || id.isEmpty ? 'Camera' : 'Camera $id';

    return Card(
      child: ExpansionTile(
        title: Text(title),
        subtitle: Text(
          (camera['lensFacing'] ?? camera['facing'] ?? '').toString(),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SelectableText(encoder.convert(camera)),
          ),
        ],
      ),
    );
  }
}
