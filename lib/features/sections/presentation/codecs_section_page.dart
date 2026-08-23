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

    final tokens = Theme.of(context).extension<ThemeTokensExtension>()!.tokens;
    final query = _query.trim().toLowerCase();
    final filtered = entries
        .where((entry) {
          if (_filter == CodecFilter.encoders && !entry.isEncoder) return false;
          if (_filter == CodecFilter.decoders && entry.isEncoder) return false;
          return query.isEmpty || entry.search.contains(query);
        })
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(getSectionMetadataProvider)('codecs', forceRefresh: true),
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
              hintText: 'search.hintCodecs'.tr,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          SizedBox(height: tokens.space2),
          Wrap(
            spacing: tokens.space1,
            runSpacing: tokens.space1,
            children: [
              for (final filter in CodecFilter.values)
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
            ...filtered.map((entry) => _CodecCard(codec: entry.data)),
        ],
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
    final tokens = Theme.of(context).extension<ThemeTokensExtension>()!.tokens;
    final name = (codec['name'] ?? codec['codecName'] ?? codec['id'])
        ?.toString();
    final typeLabel = _codecIsEncoder(codec)
        ? 'filter.encoders'.tr
        : 'filter.decoders'.tr;
    final mimeTypes = _listSummary(codec['supportedTypes'] ?? codec['types']);
    final aliases = _listSummary(codec['aliases']);
    final hardware = codec['isHardwareAccelerated']?.toString();
    final software = codec['isSoftwareOnly']?.toString();

    return Card(
      child: ExpansionTile(
        title: Text(name ?? 'codec.unnamed'.tr),
        subtitle: Text(typeLabel),
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
                SpecRow(label: 'codec.type'.tr, value: typeLabel),
                SpecRow(label: 'codec.mimeTypes'.tr, value: mimeTypes),
                SpecRow(label: 'codec.aliases'.tr, value: aliases),
                SpecRow(label: 'codec.hardwareAccelerated'.tr, value: hardware),
                SpecRow(label: 'codec.softwareOnly'.tr, value: software),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text('camera.rawPayload'.tr),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SelectableText(prettyJson(codec)),
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
}
