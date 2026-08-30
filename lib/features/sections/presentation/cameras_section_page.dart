import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/system_providers.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/app_states.dart';
import '../../../core/ui/filterable_entity_list.dart';
import '../../../core/ui/severity_chip.dart';
import '../../../core/ui/spec_row.dart';
import '../../../core/ui/section_badges.dart';
import '../../../domain/entities/info/info_section_entity.dart';
import '../../../domain/units/measurement_formatter.dart';
import '../../../features/export/presentation/export_flow.dart';
import 'widgets/raw_payload.dart';
import 'widgets/section_items.dart';

enum CameraFacingFilter { all, front, back, external }

enum _CameraKind { logical, physical, unknown }

/// Filter ids used by the [FilterableEntityList] chips.
const _facingFilterIds = {'front', 'back'};
const _kindFilterIds = {'logical', 'physical'};

/// One parsed camera with everything the UI needs precomputed, so search
/// and filtering never touch JSON again.
class _CameraEntry {
  const _CameraEntry({
    required this.data,
    required this.facing,
    required this.kind,
    required this.search,
  });

  final Map<String, dynamic> data;
  final CameraFacingFilter facing;
  final _CameraKind kind;
  final String search;
}

class CamerasSectionPage extends ConsumerStatefulWidget {
  const CamerasSectionPage({super.key});

  @override
  ConsumerState<CamerasSectionPage> createState() => _CamerasSectionPageState();
}

class _CamerasSectionPageState extends ConsumerState<CamerasSectionPage> {
  String _query = '';
  Set<String> _selectedFilters = {'all'};

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

    final logicalCount =
        entries.where((e) => e.kind == _CameraKind.logical).length;
    final physicalCount =
        entries.where((e) => e.kind == _CameraKind.physical).length;

    final query = _query.trim().toLowerCase();
    final selectedFacings = _selectedFilters.intersection(_facingFilterIds);
    final selectedKinds = _selectedFilters.intersection(_kindFilterIds);

    final filtered = entries.where((entry) {
      if (selectedFacings.isNotEmpty &&
          !_matchesFacing(selectedFacings, entry.facing)) {
        return false;
      }
      if (selectedKinds.isNotEmpty && !_matchesKind(selectedKinds, entry.kind)) {
        return false;
      }
      return query.isEmpty || entry.search.contains(query);
    }).toList(growable: false);

    final hasActiveQuery =
        query.isNotEmpty || !_selectedFilters.contains('all');

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(getSectionMetadataProvider)('cameras', forceRefresh: true),
      child: Padding(
        padding: EdgeInsets.all(context.tokens.space2),
        child: FilterableEntityList(
          searchHint: 'search.hintCameras'.tr,
          searchQuery: _query,
          onSearchChanged: (v) => setState(() => _query = v),
          filters: [
            ('all', 'filter.all'.tr),
            ('front', 'filter.front'.tr),
            ('back', 'filter.back'.tr),
            ('logical', 'camera.logical'.tr),
            ('physical', 'camera.physical'.tr),
          ],
          selectedFilters: _selectedFilters,
          onToggleFilter: _toggleFilter,
          summaryBadges: [
            SectionSummaryBadge(
              label: 'summary.lenses'.tr,
              value: '${entries.length}',
            ),
            SectionSummaryBadge(
              label: 'summary.logical'.tr,
              value: '$logicalCount',
            ),
            SectionSummaryBadge(
              label: 'summary.physical'.tr,
              value: '$physicalCount',
            ),
          ],
          hasActiveQuery: hasActiveQuery,
          emptyState: AppEmptyState(
            title: 'camera.empty'.tr,
            icon: Icons.photo_camera_outlined,
          ),
          noResultsState: AppEmptyState(
            title: 'search.noResults'.tr,
            icon: Icons.search_off_outlined,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) =>
              _CameraCard(camera: filtered[index].data),
        ),
      ),
    );
  }

  bool _matchesFacing(Set<String> selected, CameraFacingFilter facing) =>
      switch (facing) {
        CameraFacingFilter.front => selected.contains('front'),
        CameraFacingFilter.back => selected.contains('back'),
        _ => !selected.contains('front') && !selected.contains('back'),
      };

  bool _matchesKind(Set<String> selected, _CameraKind kind) => switch (kind) {
        _CameraKind.logical => selected.contains('logical'),
        _CameraKind.physical => selected.contains('physical'),
        _CameraKind.unknown =>
          !selected.contains('logical') && !selected.contains('physical'),
      };

  void _toggleFilter(String id) {
    setState(() {
      if (id == 'all') {
        _selectedFilters = {'all'};
        return;
      }
      final next = {..._selectedFilters}..remove('all');
      next.contains(id) ? next.remove(id) : next.add(id);
      _selectedFilters = next.isEmpty ? {'all'} : next;
    });
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
          kind: _resolveKind(map),
          search: searchablePayload(map),
        ),
    ];
  }

  CameraFacingFilter _resolveFacing(Map<String, dynamic> camera) {
    final label = (camera['lensFacingString'] ?? camera['facing'])
        ?.toString()
        .toLowerCase();
    if (label != null && label.isNotEmpty) {
      if (label.contains('front')) return CameraFacingFilter.front;
      if (label.contains('back') || label.contains('rear')) {
        return CameraFacingFilter.back;
      }
      if (label.contains('external')) return CameraFacingFilter.external;
    }

    // CameraCharacteristics.LENS_FACING_BACK = 0, FRONT = 1
    final rawValue = camera['lensFacing'] ?? camera['lens_facing'];
    if (rawValue is num) {
      return switch (rawValue.toInt()) {
        0 => CameraFacingFilter.back,
        1 => CameraFacingFilter.front,
        _ => CameraFacingFilter.external,
      };
    }

    return CameraFacingFilter.external;
  }

  _CameraKind _resolveKind(Map<String, dynamic> camera) {
    final deviceKind = camera['deviceKind']?.toString().toLowerCase();
    if (deviceKind == 'logical') return _CameraKind.logical;
    if (deviceKind == 'physical') return _CameraKind.physical;

    // Fallbacks for payloads predating deviceKind.
    if (camera['parentLogicalId'] != null) return _CameraKind.physical;
    final physicalIds = camera['physicalCameraIds'];
    if (physicalIds is List && physicalIds.isNotEmpty) {
      return _CameraKind.logical;
    }
    return _CameraKind.unknown;
  }
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({required this.camera});

  final Map<String, dynamic> camera;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    final id = (camera['id'] ?? camera['cameraId'] ?? camera['name'])
        ?.toString();
    final isPhysical = camera['deviceKind']?.toString() == 'physical' ||
        (camera['deviceKind'] == null && camera['parentLogicalId'] != null);

    final facingLabel = _facingLabel(camera);
    final focalMm = _doubleList(camera['focalLengthsMm'] ?? camera['focalLengths']);
    final aperturesF = _doubleList(camera['aperturesF'] ?? camera['apertures']);
    final pixelX = _intOf(camera['pixelCountX']);
    final pixelY = _intOf(camera['pixelCountY']);
    final sensorW = _doubleOf(camera['physicalSizeWidthMm']);
    final sensorH = _doubleOf(camera['physicalSizeHeightMm']);
    final orientation = _doubleOf(camera['orientationDeg']);
    final hardwareLevel = camera['hardwareLevel']?.toString();
    final parentLogicalId = camera['parentLogicalId']?.toString();
    final capabilities = _listSummary(camera['capabilities']);
    final physicalIds = _listSummary(camera['physicalCameraIds']);

    // Legacy extras kept for older payloads.
    final fpsRanges = _fpsSummary(camera['fpsRanges']);
    final outputs = _outputsSummary(camera['outputs']);
    final hasFlash = camera['hasFlash']?.toString();

    String? titleSummary;
    final summaryParts = <String>[
      if (focalMm.isNotEmpty) formatMeasurement(focalMm.first, unit: 'mm'),
      if (aperturesF.isNotEmpty) 'ƒ/${_compact(aperturesF.first)}',
      if (pixelX != null && pixelY != null)
        formatMeasurement(pixelX * pixelY / 1e6, unit: 'MP'),
    ];
    if (summaryParts.isNotEmpty) titleSummary = summaryParts.join(' • ');

    return AppCard(
      padding: EdgeInsets.all(tokens.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: tokens.space4 + 8,
                height: tokens.space4 + 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(tokens.radiusMd),
                ),
                child: Icon(
                  isPhysical ? Icons.center_focus_strong : Icons.photo_camera,
                  size: 20,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              SizedBox(width: tokens.space2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      facingLabel,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (titleSummary != null)
                      Text(
                        titleSummary,
                        style: AppText.muted(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (id != null && id.isNotEmpty && id != facingLabel)
                      Text(
                        id,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              SizedBox(width: tokens.space1),
              SeverityChip(
                dot: false,
                level:
                    isPhysical ? SeverityLevel.success : SeverityLevel.info,
                label: isPhysical
                    ? 'camera.physical'.tr
                    : 'camera.logical'.tr,
              ),
            ],
          ),
          SizedBox(height: tokens.space2),
          SpecRow(
            label: 'camera.resolution'.tr,
            value: pixelX == null || pixelY == null
                ? null
                : '$pixelX × $pixelY • '
                    '${formatMeasurement(pixelX * pixelY / 1e6, unit: 'MP')}',
            numeric: true,
          ),
          SpecRow(
            label: 'camera.apertures'.tr,
            value: aperturesF.isEmpty
                ? null
                : aperturesF.map((a) => 'ƒ/${_compact(a)}').join(', '),
            numeric: true,
          ),
          SpecRow(
            label: 'camera.focalLengths'.tr,
            value: focalMm.isEmpty
                ? null
                : focalMm.map((f) => formatMeasurement(f, unit: 'mm')).join(', '),
            numeric: true,
          ),
          SpecRow(
            label: 'camera.sensorSize'.tr,
            value: sensorW == null || sensorH == null
                ? null
                : '${formatMeasurement(sensorW)} × ${formatMeasurement(sensorH)} mm',
            numeric: true,
          ),
          SpecRow(
            label: 'camera.orientation'.tr,
            value:
                orientation == null ? null : formatMeasurement(orientation, unit: '°'),
            numeric: true,
          ),
          SpecRow(label: 'camera.hardwareLevel'.tr, value: hardwareLevel),
          SpecRow(label: 'camera.fpsRanges'.tr, value: fpsRanges),
          SpecRow(label: 'camera.outputs'.tr, value: outputs),
          SpecRow(label: 'camera.flash'.tr, value: hasFlash),
          if (isPhysical && parentLogicalId != null)
            SpecRow(
              label: 'camera.parentLogical'.tr,
              value: parentLogicalId,
            ),
          SpecRow(label: 'camera.physicalIds'.tr, value: physicalIds),
          SpecRow(label: 'camera.capabilities'.tr, value: capabilities),
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text('camera.rawPayload'.tr),
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SelectableText(prettyJson(camera)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _facingLabel(Map<String, dynamic> camera) {
    final raw = (camera['lensFacingString'] ??
            camera['lensFacing'] ??
            camera['facing'])
        ?.toString()
        .trim();
    final lower = raw?.toLowerCase() ?? '';
    if (lower.startsWith('front')) return 'filter.front'.tr;
    if (lower.startsWith('back') ||
        lower.startsWith('rear') ||
        lower == '0') {
      return 'filter.back'.tr;
    }
    if (lower.startsWith('external')) return 'filter.external'.tr;
    if (lower == '1') return 'filter.front'.tr;
    return raw == null || raw.isEmpty
        ? 'camera.unnamed'.tr
        : _humanize(raw);
  }

  String _humanize(String raw) => raw
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(' ')
      .where((p) => p.isNotEmpty)
      .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');

  List<double> _doubleList(Object? value) {
    if (value is! List) {
      final single = _doubleOf(value);
      return single == null ? const [] : [single];
    }
    return [
      for (final v in value)
        if (v is num && v.isFinite) v.toDouble(),
    ];
  }

  double? _doubleOf(Object? value) {
    final d = switch (value) {
      num v => v.toDouble(),
      String v => double.tryParse(v),
      _ => null,
    };
    return d == null || d.isNaN || d.isInfinite ? null : d;
  }

  int? _intOf(Object? value) {
    final d = _doubleOf(value);
    return d?.round();
  }

  String _compact(num value) => value
      .toDouble()
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');

  String? _listSummary(Object? value) {
    if (value is! List) return value?.toString();
    final values = value.map((e) => e.toString()).where((e) => e.isNotEmpty);
    final joined = values.join(', ');
    return joined.isEmpty ? null : joined;
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
      final min = entry['min'];
      final max = entry['max'];
      if (min == null || max == null) return null;
      return '$min-$max';
    }).whereType<String>().toList(growable: false);
    if (ranges.isEmpty) return null;
    return ranges.join(', ');
  }
}
