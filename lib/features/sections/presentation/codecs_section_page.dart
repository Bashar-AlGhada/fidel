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
import '../../../features/export/presentation/export_flow.dart';
import 'widgets/raw_payload.dart';
import 'widgets/section_items.dart';

enum CodecFilter { all, encoders, decoders }

/// Single source of truth for encoder classification so summary counts and
/// card labels can never disagree on key fallbacks.
bool _codecIsEncoder(Map<String, dynamic> codec) {
  final raw = codec['isEncoder'] ?? codec['encoder'] ?? codec['is_encoder'];
  if (raw is bool) return raw;
  return raw?.toString().toLowerCase() == 'true';
}

/// One parsed codec with everything the UI needs precomputed, so search
/// and filtering never touch JSON again.
class _CodecEntry {
  const _CodecEntry({
    required this.data,
    required this.isEncoder,
    required this.search,
  });

  final Map<String, dynamic> data;
  final bool isEncoder;
  final String search;
}

class CodecsSectionPage extends ConsumerStatefulWidget {
  const CodecsSectionPage({super.key});

  @override
  ConsumerState<CodecsSectionPage> createState() => _CodecsSectionPageState();
}

class _CodecsSectionPageState extends ConsumerState<CodecsSectionPage> {
  String _query = '';
  CodecFilter _filter = CodecFilter.all;

  InfoSectionEntity? _parsedSource;
  List<_CodecEntry> _entries = const [];

  @override
  Widget build(BuildContext context) {
    final section = ref.watch(sectionMetadataStreamProvider('codecs'));

    return Scaffold(
      appBar: AppBar(
        title: Text('section.codecs'.tr),
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
              ref.invalidate(sectionMetadataStreamProvider('codecs')),
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

    final encodersCount = entries.where((e) => e.isEncoder).length;
    final decodersCount = entries.length - encodersCount;

    final query = _query.trim().toLowerCase();
    final filtered = entries.where((entry) {
      if (_filter == CodecFilter.encoders && !entry.isEncoder) return false;
      if (_filter == CodecFilter.decoders && entry.isEncoder) return false;
      return query.isEmpty || entry.search.contains(query);
    }).toList(growable: false);

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(getSectionMetadataProvider)('codecs', forceRefresh: true),
      child: Padding(
        padding: EdgeInsets.all(context.tokens.space2),
        child: FilterableEntityList(
          searchHint: 'search.hintCodecs'.tr,
          searchQuery: _query,
          onSearchChanged: (v) => setState(() => _query = v),
          filters: [
            ('all', 'filter.all'.tr),
            ('encoders', 'filter.encoders'.tr),
            ('decoders', 'filter.decoders'.tr),
          ],
          selectedFilters: {_filter.name},
          onToggleFilter: (id) => setState(
            () => _filter =
                CodecFilter.values.firstWhere((f) => f.name == id),
          ),
          summaryBadges: [
            SectionSummaryBadge(
              label: 'summary.total'.tr,
              value: '${entries.length}',
            ),
            SectionSummaryBadge(
              label: 'summary.encoders'.tr,
              value: '$encodersCount',
            ),
            SectionSummaryBadge(
              label: 'summary.decoders'.tr,
              value: '$decodersCount',
            ),
          ],
          hasActiveQuery:
              query.isNotEmpty || _filter != CodecFilter.all,
          emptyState: AppEmptyState(
            title: 'codec.empty'.tr,
            icon: Icons.movie_filter_outlined,
          ),
          noResultsState: AppEmptyState(
            title: 'search.noResults'.tr,
            icon: Icons.search_off_outlined,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) =>
              _CodecCard(codec: filtered[index].data),
        ),
      ),
    );
  }

  List<_CodecEntry> _parseEntries(InfoSectionEntity section) {
    final raw = findItemText(section, 'codecs.codecs');
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
      AppLog.warn('Failed to parse codecs payload', error: e, stackTrace: st);
      return const [];
    }

    return [
      for (final map in maps)
        _CodecEntry(
          data: map,
          isEncoder: _codecIsEncoder(map),
          search: searchablePayload(map),
        ),
    ];
  }
}

class _CodecCard extends StatelessWidget {
  const _CodecCard({required this.codec});

  final Map<String, dynamic> codec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    final name = (codec['name'] ?? codec['codecName'] ?? codec['id'])
        ?.toString();
    final isEncoder = _codecIsEncoder(codec);
    final typeLabel =
        isEncoder ? 'filter.encoders'.tr : 'filter.decoders'.tr;
    final mimeTypes = _listSummary(codec['supportedTypes'] ?? codec['types']);
    final aliases = _listSummary(codec['aliases']);

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
                  isEncoder ? Icons.upload_outlined : Icons.download_outlined,
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
                      name ?? 'codec.unnamed'.tr,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (mimeTypes != null)
                      Text(
                        mimeTypes,
                        style: AppText.muted(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              SizedBox(width: tokens.space1),
              SeverityChip(
                dot: false,
                level: isEncoder ? SeverityLevel.success : SeverityLevel.info,
                label: typeLabel,
              ),
            ],
          ),
          SizedBox(height: tokens.space2),
          SpecRow(label: 'codec.type'.tr, value: typeLabel),
          SpecRow(label: 'codec.mimeTypes'.tr, value: mimeTypes),
          SpecRow(label: 'codec.aliases'.tr, value: aliases),
          SpecRow(
            label: 'codec.hardwareAccelerated'.tr,
            value: _boolLabel(codec['isHardwareAccelerated']),
          ),
          SpecRow(
            label: 'codec.softwareOnly'.tr,
            value: _boolLabel(codec['isSoftwareOnly']),
          ),
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text('camera.rawPayload'.tr),
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SelectableText(prettyJson(codec)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _boolLabel(Object? raw) => switch (raw?.toString()) {
        'true' => 'common.yes'.tr,
        'false' => 'common.no'.tr,
        final other => other,
      };

  String? _listSummary(Object? value) {
    if (value is! List) return value?.toString();
    final values = value.map((e) => e.toString()).where((e) => e.isNotEmpty);
    final joined = values.join(', ');
    return joined.isEmpty ? null : joined;
  }
}
