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

enum CodecFilter { all, encoders, decoders }

class CodecsSectionPage extends ConsumerStatefulWidget {
  const CodecsSectionPage({super.key});

  @override
  ConsumerState<CodecsSectionPage> createState() => _CodecsSectionPageState();
}

class _CodecsSectionPageState extends ConsumerState<CodecsSectionPage> {
  String _query = '';
  CodecFilter _filter = CodecFilter.all;

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

    final section = ref.watch(sectionMetadataStreamProvider('codecs'));

    return Scaffold(
      appBar: AppBar(
        title: Text('section.codecs'.tr),
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
    final codecs = _extractCodecs(section);
    final encodersCount = codecs.where(_isEncoder).length;
    final decodersCount = codecs.length - encodersCount;

    final filtered = codecs
        .where((codec) {
          if (_filter != CodecFilter.all) {
            final enc = _isEncoder(codec);
            if (_filter == CodecFilter.encoders && !enc) return false;
            if (_filter == CodecFilter.decoders && enc) return false;
          }
          if (_query.trim().isEmpty) return true;
          final q = _query.trim().toLowerCase();
          return _searchable(codec).contains(q);
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
                  _SummaryBadge(label: 'Total', value: '${codecs.length}'),
                  _SummaryBadge(label: 'Encoders', value: '$encodersCount'),
                  _SummaryBadge(label: 'Decoders', value: '$decodersCount'),
                ],
              ),
            ),
          ),
          SizedBox(height: tokens.space2),
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
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
              _FilterChip(
                selected: _filter == CodecFilter.all,
                label: 'filter.all'.tr,
                onTap: () => setState(() => _filter = CodecFilter.all),
              ),
              _FilterChip(
                selected: _filter == CodecFilter.encoders,
                label: 'filter.encoders'.tr,
                onTap: () => setState(() => _filter = CodecFilter.encoders),
              ),
              _FilterChip(
                selected: _filter == CodecFilter.decoders,
                label: 'filter.decoders'.tr,
                onTap: () => setState(() => _filter = CodecFilter.decoders),
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
            ...filtered.map((codec) => _CodecCard(codec: codec)),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _extractCodecs(InfoSectionEntity section) {
    final item = section.items.cast<InfoItemEntity?>().firstWhere(
      (it) => it?.labelKey == 'codecs.codecs',
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

  bool _isEncoder(Map<String, dynamic> codec) {
    final raw = codec['isEncoder'] ?? codec['encoder'] ?? codec['is_encoder'];
    if (raw is bool) return raw;
    return raw?.toString().toLowerCase() == 'true';
  }

  String _searchable(Map<String, dynamic> codec) {
    final encoder = const JsonEncoder.withIndent(' ');
    return encoder.convert(codec).toLowerCase();
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

class _CodecCard extends StatelessWidget {
  const _CodecCard({required this.codec});

  final Map<String, dynamic> codec;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ThemeTokensExtension>()!.tokens;
    final encoder = const JsonEncoder.withIndent('  ');
    final name = (codec['name'] ?? codec['codecName'] ?? codec['id'])
        ?.toString();
    final isEncoder =
        (codec['isEncoder'] ?? codec['encoder']) == true ||
        codec['isEncoder']?.toString().toLowerCase() == 'true';
    final label = isEncoder ? 'filter.encoders'.tr : 'filter.decoders'.tr;
    final mimeTypes = _listSummary(codec['supportedTypes'] ?? codec['types']);
    final aliases = _listSummary(codec['aliases']);
    final hardware = codec['isHardwareAccelerated']?.toString();
    final software = codec['isSoftwareOnly']?.toString();

    return Card(
      child: ExpansionTile(
        title: Text(name ?? 'Codec'),
        subtitle: Text(label),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(tokens.space2, 0, tokens.space2, tokens.space2),
            child: Column(
              children: [
                _SpecRow(label: 'Type', value: label),
                _SpecRow(label: 'MIME types', value: mimeTypes),
                _SpecRow(label: 'Aliases', value: aliases),
                _SpecRow(label: 'Hardware accelerated', value: hardware),
                _SpecRow(label: 'Software only', value: software),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: const Text('Advanced raw payload'),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SelectableText(encoder.convert(codec)),
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
