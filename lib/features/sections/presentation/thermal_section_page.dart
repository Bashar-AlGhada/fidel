import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/system_providers.dart';
import '../../../application/providers/units_providers.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/app_meter.dart';
import '../../../core/ui/app_states.dart';
import '../../../core/ui/glass_card.dart';
import '../../../core/ui/severity_chip.dart';
import '../../../domain/entities/info/info_section_entity.dart';
import '../../../domain/units/unit_preferences.dart';
import '../../../domain/units/units_formatter.dart';
import '../../../features/export/presentation/export_flow.dart';
import 'widgets/section_items.dart';
import 'widgets/thermal_payload.dart';
import 'widgets/thermal_severity.dart';

class ThermalSectionPage extends ConsumerStatefulWidget {
  const ThermalSectionPage({super.key});

  @override
  ConsumerState<ThermalSectionPage> createState() => _ThermalSectionPageState();
}

class _ParsedThermal {
  const _ParsedThermal({
    this.rows = const [],
    this.statusWord,
    this.timestampMs,
  });

  final List<_TempRow> rows;
  final String? statusWord;
  final int? timestampMs;
}

class _TempRow {
  const _TempRow({required this.label, required this.value, this.type});

  final String label;
  final String? type;
  final double value;
}

class _ThermalSectionPageState extends ConsumerState<ThermalSectionPage> {
  InfoSectionEntity? _parsedSource;
  _ParsedThermal _parsed = const _ParsedThermal();

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
    if (!identical(_parsedSource, section)) {
      _parsedSource = section;
      _parsed = _parse(section);
    }
    final parsed = _parsed;

    final sorted = [...parsed.rows]..sort((a, b) => b.value.compareTo(a.value));
    final maxTemp = sorted.isEmpty ? null : sorted.first.value;

    return ListView(
      padding: EdgeInsets.all(context.tokens.space2),
      children: [
        _StatusHeader(
          statusWord: parsed.statusWord,
          maxTemp: maxTemp,
          timestampMs: parsed.timestampMs,
          prefs: prefs,
          formatter: formatter,
        ),
        SizedBox(height: context.tokens.space3),
        if (sorted.isEmpty)
          AppEmptyState(
            title: 'thermal.noTemperatures'.tr,
            icon: Icons.thermostat,
          )
        else ...[
          Text(
            'thermal.zonesTitle'.tr,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
          ),
          SizedBox(height: context.tokens.space2),
          for (final t in sorted) ...[
            _ZoneCard(row: t, prefs: prefs, formatter: formatter),
            SizedBox(height: context.tokens.space2),
          ],
        ],
      ],
    );
  }

  /// Parses both structured `thermal.zones` and legacy `thermal.temperatures`.
  _ParsedThermal _parse(InfoSectionEntity section) {
    final rows = <_TempRow>[];

    void collect(String? raw) {
      if (raw == null || raw.isEmpty || rows.isNotEmpty) return;
      try {
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
      } catch (e, st) {
        AppLog.warn('Failed to parse thermal payload', error: e, stackTrace: st);
      }
    }

    collect(findItemText(section, 'thermal.zones'));
    collect(findItemText(section, 'thermal.temperatures'));

    int? timestamp;
    final rawTs = findItemText(section, 'thermal.timestampMs');
    if (rawTs != null) timestamp = int.tryParse(rawTs);

    return _ParsedThermal(
      rows: rows,
      statusWord: findItemText(section, 'thermal.thermalStatusLabel'),
      timestampMs: timestamp,
    );
  }
}

/// Severity hero: chip + big reading + timestamp caption.
class _StatusHeader extends StatelessWidget {
  const _StatusHeader({
    required this.statusWord,
    required this.maxTemp,
    required this.timestampMs,
    required this.prefs,
    required this.formatter,
  });

  final String? statusWord;
  final double? maxTemp;
  final int? timestampMs;
  final UnitPreferences prefs;
  final UnitsFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final level = thermalSeverityForWord(statusWord);
    final accent = thermalTokenColor(context, level);

    final temp = maxTemp;
    final headline = temp == null
        ? (statusWord == null
            ? 'availability.unavailable'.tr
            : thermalStatusLabel(statusWord!))
        : formatter.formatTemperature(
            celsius: temp,
            unit: prefs.temperature,
          );

    return GlassCard(
      gradientTint: true,
      highlightBorder: level == SeverityLevel.danger,
      padding: EdgeInsets.all(tokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (statusWord != null)
                SeverityChip(level: level, label: thermalStatusLabel(statusWord!))
              else
                Text(
                  'thermal.currentStatus'.tr,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const Spacer(),
              if (timestampMs != null)
                Text(
                  DateTime.fromMillisecondsSinceEpoch(timestampMs!).toLocal()
                      .toString(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          SizedBox(height: tokens.space2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              headline,
              style: AppText.heroNumeric(context, color: accent),
            ),
          ),
          if (maxTemp != null && statusWord != null) ...[
            SizedBox(height: tokens.space1 / 2),
            Text(
              'thermal.currentStatus'.tr,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One thermal zone with banded temperature coloring and a mini meter.
class _ZoneCard extends StatelessWidget {
  const _ZoneCard({
    required this.row,
    required this.prefs,
    required this.formatter,
  });

  final _TempRow row;
  final UnitPreferences prefs;
  final UnitsFormatter formatter;

  Color? _bandColor(BuildContext context) {
    final tokens = context.tokens;
    if (row.value >= 55) return tokens.dangerColor;
    if (row.value >= 45) return tokens.warningColor;
    return Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final color = _bandColor(context);

    return AppCard(
      padding: EdgeInsets.all(tokens.space2),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: tokens.space4 + 8,
                height: tokens.space4 + 8,
                decoration: BoxDecoration(
                  color: (color ?? theme.colorScheme.primary).withValues(
                    alpha: 0.15,
                  ),
                  borderRadius: BorderRadius.circular(tokens.radiusMd),
                ),
                child: Icon(
                  Icons.device_thermostat,
                  size: 22,
                  color: color ?? theme.colorScheme.primary,
                ),
              ),
              SizedBox(width: tokens.space2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.label, style: theme.textTheme.titleMedium),
                    if (row.type != null && row.type!.isNotEmpty)
                      Text(
                        row.type!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              SizedBox(width: tokens.space2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatter.formatTemperature(
                    celsius: row.value,
                    unit: prefs.temperature,
                  ),
                  style: AppText.numeric(context, color: color),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.space2),
          AppMeter(
            value: (row.value.clamp(0, 100)) / 100,
            height: 6,
            color: color,
          ),
        ],
      ),
    );
  }
}
