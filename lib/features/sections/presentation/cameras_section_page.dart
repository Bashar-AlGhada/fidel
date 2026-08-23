import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/system_providers.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_states.dart';
import '../../../domain/entities/info/info_section_entity.dart';
import '../../../features/export/presentation/export_flow.dart';
import 'widgets/raw_payload.dart';
import 'widgets/section_cards.dart';
import 'widgets/section_items.dart';

enum CameraFacingFilter { all, front, back, external }

/// One parsed camera with everything the UI needs precomputed, so search
/// and filtering never touch JSON again.
class _CameraEntry {
  const _CameraEntry({
    required this.data,
    required this.facing,
    required this.search,
  });

  final Map<String, dynamic> data;
  final CameraFacingFilter facing;
  final String search;
}

class CamerasSectionPage extends ConsumerStatefulWidget {
  const CamerasSectionPage({super.key});

  @override
  ConsumerState<CamerasSectionPage> createState() => _CamerasSectionPageState();
}

class _CamerasSectionPageState extends ConsumerState<CamerasSectionPage> {
  String _query = '';
  CameraFacingFilter _filter = CameraFacingFilter.all;

  InfoSectionEntity? _parsedSource;
  List<_CameraEntry> _entries = const [];

  @override
  Widget build(BuildContext context) {
    final section = ref.watch(sectionMetadataStreamProvider('cameras'));

    return Scaffold(
      appBar: AppBar(
        title: Text('section.cameras'.tr),
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
        data: (value) => _buildLoaded(context, value),
        loading: () => const AppLoadingState(),
        error: (err, st) => AppErrorState(
          title: 'availability.unavailable'.tr,
          message: '$err',
          actionLabel: 'action.retry'.tr,
          onAction: () =>
              ref.invalidate(sectionMetadataStreamProvider('cameras')),
        ),
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, InfoSectionEntity section) {
    if (!identical(_parsedSource, section)) {
      _parsedSource = section;
      _entries = _parseEntries(section);
    }
    final entries = _entries;

    final totalCount = entries.length;
    final frontCount = entries
        .where((e) => e.facing == CameraFacingFilter.front)
        .length;
    final backCount = entries
        .where((e) => e.facing == CameraFacingFilter.back)
        .length;
    final externalCount = entries
        .where((e) => e.facing == CameraFacingFilter.external)
        .length;

    final tokens = Theme.of(context).extension<ThemeTokensExtension>()!.tokens;
    final query = _query.trim().toLowerCase();
    final filtered = entries
        .where((entry) {
          if (_filter != CameraFacingFilter.all && entry.facing != _filter) {
            return false;
          }
          return query.isEmpty || entry.search.contains(query);
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
                  SectionSummaryBadge(
                    label: 'summary.total'.tr,
                    value: '$totalCount',
                  ),
                  SectionSummaryBadge(
                    label: 'summary.front'.tr,
                    value: '$frontCount',
                  ),
                  SectionSummaryBadge(
                    label: 'summary.back'.tr,
                    value: '$backCount',
                  ),
                  SectionSummaryBadge(
                    label: 'summary.external'.tr,
                    value: '$externalCount',
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: tokens.space2),
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'action.clear'.tr,
                      onPressed: () => setState(() => _query = ''),
                    ),
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
              for (final filter in CameraFacingFilter.values)
                SectionFilterChip(
                  selected: _filter == filter,
                  label: 'filter.${filter.name}'.tr,
                  onTap: () => setState(() => _filter = filter),
                ),
            ],
          ),
          SizedBox(height: tokens.space2),
          if (filtered.isEmpty)
            AppEmptyState(
              title: 'search.noResults'.tr,
              icon: Icons.search_off_outlined,
            )
          else
            ...filtered.map((entry) => _CameraCard(camera: entry.data)),
        ],
      ),
    );
  }

  List<_CameraEntry> _parseEntries(InfoSectionEntity section) {
    final raw = findItemText(section, 'cameras.cameras');
    if (raw == null || raw.isEmpty) return const [];

    List<Map<String, dynamic>> maps;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        maps = decoded
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList(growable: false);
      } else if (decoded is Map) {
        maps = [decoded.cast<String, dynamic>()];
      } else {
        return const [];
      }
    } catch (e, st) {
      AppLog.warn('Failed to parse cameras payload', error: e, stackTrace: st);
      return const [];
    }

    return [
      for (final map in maps)
        _CameraEntry(
          data: map,
          facing: _resolveFacing(map),
          search: searchablePayload(map),
        ),
    ];
  }

  CameraFacingFilter _resolveFacing(Map<String, dynamic> camera) {
    final label = camera['lensFacingString']?.toString().toLowerCase();
    if (label != null && label.isNotEmpty) {
      if (label.contains('front')) return CameraFacingFilter.front;
      if (label.contains('back') || label.contains('rear')) {
        return CameraFacingFilter.back;
      }
      if (label.contains('external')) return CameraFacingFilter.external;
    }

    // CameraCharacteristics.LENS_FACING_BACK = 0, FRONT = 1
    final rawValue =
        camera['lensFacing'] ?? camera['facing'] ?? camera['lens_facing'];
    if (rawValue is num) {
      return switch (rawValue.toInt()) {
        0 => CameraFacingFilter.back,
        1 => CameraFacingFilter.front,
        _ => CameraFacingFilter.external,
      };
    }

    return CameraFacingFilter.external;
  }
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({required this.camera});

  final Map<String, dynamic> camera;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ThemeTokensExtension>()!.tokens;
    final id = (camera['cameraId'] ?? camera['id'] ?? camera['name'])
        ?.toString();
    final title = id == null || id.isEmpty
        ? 'camera.unnamed'.tr
        : 'camera.title'.trParams({'id': id});
    final facing =
        (camera['lensFacingString'] ?? camera['lensFacing'] ?? camera['facing'])
            ?.toString();
    final level = camera['hardwareLevel']?.toString();
    final focal = _numString(
      camera['focalLengthsMm'] ?? camera['focalLengths'],
    );
    final apertures = _numString(camera['apertures']);
    final physicalIds = _listSummary(camera['physicalCameraIds']);
    final capabilities = _listSummary(camera['capabilities']);
    final outputs = _outputsSummary(camera['outputs']);
    final fpsRanges = _fpsSummary(camera['fpsRanges']);
    final hasFlash = camera['hasFlash']?.toString();

    return Card(
      child: ExpansionTile(
        title: Text(title),
        subtitle: Text(facing ?? 'camera.unknownFacing'.tr),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.space2,
              0,
              tokens.space2,
              tokens.space2,
            ),
            child: Column(
              children: [
                SpecRow(label: 'camera.facing'.tr, value: facing),
                SpecRow(label: 'camera.hardwareLevel'.tr, value: level),
                SpecRow(label: 'camera.focalLengths'.tr, value: focal),
                SpecRow(label: 'camera.apertures'.tr, value: apertures),
                SpecRow(label: 'camera.fpsRanges'.tr, value: fpsRanges),
                SpecRow(label: 'camera.outputs'.tr, value: outputs),
                SpecRow(label: 'camera.flash'.tr, value: hasFlash),
                SpecRow(label: 'camera.physicalIds'.tr, value: physicalIds),
                SpecRow(label: 'camera.capabilities'.tr, value: capabilities),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text('camera.rawPayload'.tr),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SelectableText(prettyJson(camera)),
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
          .map(_compactNumber)
          .toList(growable: false);
      return parts.isEmpty ? null : parts.join(', ');
    }
    return value?.toString();
  }

  String? _outputsSummary(Object? value) {
    if (value is! List) return value?.toString();
    final entries = value
        .whereType<Map>()
        .map((entry) {
          final map = entry.cast<String, dynamic>();
          final sizes = map['sizes'];
          final count = sizes is List ? sizes.length : 0;
          final format = map['format']?.toString() ?? '?';
          return '$format($count)';
        })
        .toList(growable: false);
    if (entries.isEmpty) return null;
    return entries.join(', ');
  }

  String? _fpsSummary(Object? value) {
    if (value is! List) return value?.toString();
    final ranges = value
        .whereType<Map>()
        .map((entry) {
          final min = entry['min'];
          final max = entry['max'];
          if (min == null || max == null) return null;
          return '$min-$max';
        })
        .whereType<String>()
        .toList(growable: false);
    if (ranges.isEmpty) return null;
    return ranges.join(', ');
  }

  String _compactNumber(num value) {
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
