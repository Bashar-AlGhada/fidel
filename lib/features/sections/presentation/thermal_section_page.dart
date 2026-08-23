import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/system_providers.dart';
import '../../../application/providers/units_providers.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_states.dart';
import '../../../domain/entities/info/info_section_entity.dart';
import '../../../domain/units/unit_preferences.dart';
import '../../../domain/units/units_formatter.dart';
import '../../../features/export/presentation/export_flow.dart';
import 'widgets/section_items.dart';
import 'widgets/thermal_payload.dart';

class ThermalSectionPage extends ConsumerStatefulWidget {
  const ThermalSectionPage({super.key});

  @override
  ConsumerState<ThermalSectionPage> createState() => _ThermalSectionPageState();
}

class _ThermalSectionPageState extends ConsumerState<ThermalSectionPage> {
  InfoSectionEntity? _parsedSource;
  List<_TempRow> _rows = const [];

  @override
  Widget build(BuildContext context) {
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
            tooltip: 'action.export'.tr,
            onPressed: () =>
                exportSectionFlow(context, ref, section.asData?.value),
          ),
        ],
      ),
      body: section.when(
        skipLoadingOnReload: true,
        data: (value) => _buildLoaded(value, prefs, formatter),
        loading: () => const AppLoadingState(),
        error: (err, st) => AppErrorState(
          title: 'availability.unavailable'.tr,
          message: '$err',
          actionLabel: 'action.retry'.tr,
          onAction: () =>
              ref.invalidate(sectionMetadataStreamProvider('thermal')),
        ),
      ),
    );
  }

  Widget _buildLoaded(
    InfoSectionEntity section,
    UnitPreferences prefs,
    UnitsFormatter formatter,
  ) {
    final tokens = Theme.of(context).extension<ThemeTokensExtension>()!.tokens;
    if (!identical(_parsedSource, section)) {
      _parsedSource = section;
      _rows = _extractTemps(section);
    }
    final temps = _rows;

    final maxTemp = temps
        .map((e) => e.value)
        .fold<double?>(null, (p, v) => p == null ? v : (v > p ? v : p));

    final sorted = [...temps]..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: EdgeInsets.all(tokens.space2),
      children: [
        Card(
          child: Padding(
            padding: EdgeInsets.all(tokens.space2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'thermal.currentStatus'.tr,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  findItemText(section, 'thermal.thermalStatus') ??
                      'availability.unavailable'.tr,
                ),
                if (maxTemp != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${'thermal.maxTemp'.tr}: ${formatter.formatTemperature(celsius: maxTemp, unit: prefs.temperature)}',
                  ),
                ],
                ..._timestampLine(section),
              ],
            ),
          ),
        ),
        SizedBox(height: tokens.space2),
        for (final t in sorted)
          Card(
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
          ),
        if (sorted.isEmpty)
          AppEmptyState(
            title: 'thermal.noTemperatures'.tr,
            icon: Icons.thermostat,
          ),
      ],
    );
  }

  List<Widget> _timestampLine(InfoSectionEntity section) {
    final timestampMs = findItemText(section, 'thermal.timestampMs');
    final parsed = int.tryParse(timestampMs ?? '');
    if (parsed == null) return const [];
    final local = DateTime.fromMillisecondsSinceEpoch(parsed).toLocal();
    return [
      const SizedBox(height: 8),
      Text('${'thermal.timestamp'.tr}: $local'),
    ];
  }

  List<_TempRow> _extractTemps(InfoSectionEntity section) {
    final raw = findItemText(section, 'thermal.temperatures');
    if (raw == null || raw.isEmpty) return const [];

    try {
      final rows = <_TempRow>[];
      for (final map in normalizeThermalPayload(jsonDecode(raw))) {
        final value = temperatureValueOf(map);
        if (value == null) continue;

        final label =
            (map['name'] ?? map['label'] ?? map['source'] ?? map['type'])
                ?.toString()
                .trim();
        rows.add(
          _TempRow(
            label: (label == null || label.isEmpty)
                ? 'thermal.rowFallback'.tr
                : label,
            type: map['type']?.toString(),
            value: value,
          ),
        );
      }
      return rows;
    } catch (e, st) {
      AppLog.warn('Failed to parse thermal payload', error: e, stackTrace: st);
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
