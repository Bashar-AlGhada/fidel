import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/export_providers.dart';
import '../../../application/providers/system_providers.dart';
import '../../../application/sampling/active_module.dart';
import '../../../application/sampling/sampling_provider.dart';
import '../../../core/theme/theme_tokens.dart';
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
    final tokens = Theme.of(context).extension<ThemeTokensExtension>()!.tokens;
    final cameras = _extractCameras(section);
    final totalCount = cameras.length;
    final frontCount = cameras
      .where((camera) => _cameraFacing(camera) == CameraFacingFilter.front)
      .length;
    final backCount = cameras
      .where((camera) => _cameraFacing(camera) == CameraFacingFilter.back)
      .length;
    final externalCount = cameras
      .where((camera) => _cameraFacing(camera) == CameraFacingFilter.external)
      .length;

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
        padding: EdgeInsets.all(tokens.space2),
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(tokens.space2),
              child: Wrap(
                spacing: tokens.space2,
                runSpacing: tokens.space1,
                children: [
                  _SummaryBadge(label: 'Total', value: '$totalCount'),
                  _SummaryBadge(label: 'Front', value: '$frontCount'),
                  _SummaryBadge(label: 'Back', value: '$backCount'),
                  _SummaryBadge(label: 'External', value: '$externalCount'),
                ],
              ),
            ),
          ),
          SizedBox(height: tokens.space2),
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'search.hintCameras'.tr,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          SizedBox(height: tokens.space2),
          Wrap(
            spacing: tokens.space1,
            runSpacing: tokens.space1,
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
          SizedBox(height: tokens.space2),
          if (filtered.isEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.all(tokens.space2),
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
    final rawValue =
        camera['lensFacing'] ??
        camera['facing'] ??
        camera['lens_facing'] ??
        camera['lensFacingString'];

    if (rawValue is num) {
      final v = rawValue.toInt();
      if (v == 0) return CameraFacingFilter.front;
      if (v == 1) return CameraFacingFilter.back;
      return CameraFacingFilter.external;
    }

    final raw = rawValue?.toString().toLowerCase();
    if (raw == null) return CameraFacingFilter.external;
    if (raw.contains('front')) return CameraFacingFilter.front;
    if (raw.contains('back') || raw.contains('rear')) {
      return CameraFacingFilter.back;
    }
    if (raw == '0') return CameraFacingFilter.front;
    if (raw == '1') return CameraFacingFilter.back;
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

class _SummaryBadge extends StatelessWidget {
  const _SummaryBadge({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label: $value', style: theme.textTheme.labelLarge),
    );
  }
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({required this.camera});

  final Map<String, dynamic> camera;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ThemeTokensExtension>()!.tokens;
    final encoder = const JsonEncoder.withIndent('  ');
    final id = (camera['cameraId'] ?? camera['id'] ?? camera['name'])
        ?.toString();
    final title = id == null || id.isEmpty ? 'Camera' : 'Camera $id';
    final facing = (camera['lensFacingString'] ?? camera['lensFacing'] ?? camera['facing'])
        ?.toString();
    final level = camera['hardwareLevel']?.toString();
    final focal = _numString(camera['focalLengthsMm'] ?? camera['focalLengths']);
    final apertures = _numString(camera['apertures']);
    final physicalIds = _listSummary(camera['physicalCameraIds']);
    final capabilities = _listSummary(camera['capabilities']);
    final outputs = _outputsSummary(camera['outputs']);
    final fpsRanges = _fpsSummary(camera['fpsRanges']);
    final hasFlash = camera['hasFlash']?.toString();

    return Card(
      child: ExpansionTile(
        title: Text(title),
        subtitle: Text(facing ?? 'Unknown facing'),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(tokens.space2, 0, tokens.space2, tokens.space2),
            child: Column(
              children: [
                _SpecRow(label: 'Facing', value: facing),
                _SpecRow(label: 'Hardware level', value: level),
                _SpecRow(label: 'Focal lengths', value: focal),
                _SpecRow(label: 'Apertures', value: apertures),
                _SpecRow(label: 'FPS ranges', value: fpsRanges),
                _SpecRow(label: 'Outputs', value: outputs),
                _SpecRow(label: 'Flash', value: hasFlash),
                _SpecRow(label: 'Physical IDs', value: physicalIds),
                _SpecRow(label: 'Capabilities', value: capabilities),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: const Text('Advanced raw payload'),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SelectableText(encoder.convert(camera)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _listSummary(Object? value) {
    if (value is! List) return value?.toString();
    final values = value.map((e) => e.toString()).where((e) => e.isNotEmpty);
    final joined = values.join(', ');
    return joined.isEmpty ? null : joined;
  }

  String? _numString(Object? value) {
    if (value is List) {
      final parts = value
          .whereType<num>()
          .map((e) => e.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), ''))
          .toList(growable: false);
      return parts.isEmpty ? null : parts.join(', ');
    }
    return value?.toString();
  }

  String? _outputsSummary(Object? value) {
    if (value is! List) return value?.toString();
    final entries = value.whereType<Map>().map((entry) {
      final map = entry.cast<String, dynamic>();
      final sizes = map['sizes'];
      final count = sizes is List ? sizes.length : 0;
      final format = map['format']?.toString() ?? '?';
      return '$format($count)';
    }).toList(growable: false);
    if (entries.isEmpty) return null;
    return entries.join(', ');
  }

  String? _fpsSummary(Object? value) {
    if (value is! List) return value?.toString();
    final ranges = value.whereType<Map>().map((entry) {
      final map = entry.cast<String, dynamic>();
      final min = map['min'];
      final max = map['max'];
      if (min == null || max == null) return null;
      return '$min-$max';
    }).whereType<String>().toList(growable: false);
    if (ranges.isEmpty) return null;
    return ranges.join(', ');
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label)),
          const SizedBox(width: 8),
          Expanded(child: Text(value!)),
        ],
      ),
    );
  }
}
