import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/export_providers.dart';
import '../../../application/providers/system_providers.dart';
import '../../../application/providers/units_providers.dart';
import '../../../application/sampling/active_module.dart';
import '../../../application/sampling/sampling_provider.dart';
import '../../../domain/entities/info/info_item_entity.dart';
import '../../../domain/entities/info/info_section_entity.dart';
import '../../../domain/units/unit_preferences.dart';
import '../../../domain/units/units_formatter.dart';
import '../../../features/export/presentation/export_format_sheet.dart';

class ThermalSectionPage extends ConsumerWidget {
  const ThermalSectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeModule = ref.watch(activeModuleProvider);
    if (activeModule != ActiveModule.info) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(activeModuleProvider.notifier).setModule(ActiveModule.info);
      });
    }

    final section = ref.watch(sectionMetadataStreamProvider('thermal'));
    final prefs = ref
        .watch(unitPreferencesStreamProvider)
        .maybeWhen(data: (p) => p, orElse: () => UnitPreferences.defaults);
    final formatter = ref.watch(unitsFormatterProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('section.thermal'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () => _export(context, ref, section.asData?.value),
          ),
        ],
      ),
      body: section.when(
        data: (value) =>
            _ThermalView(section: value, prefs: prefs, formatter: formatter),
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

class _ThermalView extends StatelessWidget {
  const _ThermalView({
    required this.section,
    required this.prefs,
    required this.formatter,
  });

  final InfoSectionEntity section;
  final UnitPreferences prefs;
  final UnitsFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final status = _findText(section, 'thermal.thermalStatus');
    final timestampMs = _findText(section, 'thermal.timestampMs');
    final temps = _extractTemps(section);

    final maxTemp = temps
        .map((e) => e.value)
        .fold<double?>(null, (p, v) => p == null ? v : (v > p ? v : p));

    final sorted = [...temps]..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'thermal.currentStatus'.tr,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(status ?? 'availability.unavailable'.tr),
                if (maxTemp != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${'thermal.maxTemp'.tr}: ${formatter.formatTemperature(celsius: maxTemp, unit: prefs.temperature)}',
                  ),
                ],
                if (timestampMs != null) ...[
                  const SizedBox(height: 8),
                  Text('${'thermal.timestamp'.tr}: $timestampMs'),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...sorted.map((t) {
          return Card(
            child: ListTile(
              title: Text(t.label),
              trailing: Text(
                formatter.formatTemperature(
                  celsius: t.value,
                  unit: prefs.temperature,
                ),
              ),
              subtitle: t.type == null ? null : Text(t.type!),
            ),
          );
        }),
        if (sorted.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('thermal.noTemperatures'.tr),
            ),
          ),
      ],
    );
  }

  String? _findText(InfoSectionEntity section, String labelKey) {
    for (final item in section.items) {
      if (item.labelKey != labelKey) continue;
      return item.value?.text;
    }
    return null;
  }

  List<_TempRow> _extractTemps(InfoSectionEntity section) {
    final item = section.items.cast<InfoItemEntity?>().firstWhere(
      (it) => it?.labelKey == 'thermal.temperatures',
      orElse: () => null,
    );
    final raw = item?.value?.text;
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      final rows = switch (decoded) {
        List list => list.whereType<Map>().map(
          (rawMap) => rawMap.cast<String, dynamic>(),
        ),
        Map map => map.entries.map((entry) {
          final value = entry.value;
          if (value is Map) return value.cast<String, dynamic>();
          return <String, dynamic>{'name': entry.key, 'valueC': value};
        }),
        _ => const Iterable<Map<String, dynamic>>.empty(),
      };

      return rows
          .whereType<Map>()
          .map((rawMap) {
            final map = rawMap;
            final value =
                map['valueC'] ?? map['value'] ?? map['tempC'] ?? map['celsius'];
            final numValue = switch (value) {
              num v => v.toDouble(),
              String v => double.tryParse(v) ?? double.nan,
              _ => double.nan,
            };
            if (numValue.isNaN || numValue.isInfinite) return null;

            final label =
                (map['name'] ?? map['label'] ?? map['source'] ?? map['type'])
                    ?.toString()
                    .trim();
            return _TempRow(
              label: (label == null || label.isEmpty) ? 'Temperature' : label,
              type: map['type']?.toString(),
              value: numValue,
            );
          })
          .whereType<_TempRow>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}

class _TempRow {
  const _TempRow({required this.label, required this.value, this.type});

  final String label;
  final String? type;
  final double value;
}
