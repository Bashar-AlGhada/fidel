import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/export_providers.dart';
import '../../../application/providers/system_providers.dart';
import '../../../application/providers/units_providers.dart';
import '../../../application/sampling/active_module.dart';
import '../../../application/sampling/sampling_provider.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/app_section.dart';
import '../../../domain/entities/info/info_section_entity.dart';
import '../../../domain/units/unit_preferences.dart';
import '../../../domain/units/units_formatter.dart';
import '../../../features/export/presentation/export_format_sheet.dart';
import '../../sections/sections_registry.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeModule = ref.watch(activeModuleProvider);
    if (activeModule != ActiveModule.dashboard) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(activeModuleProvider.notifier)
            .setModule(ActiveModule.dashboard);
      });
    }

    final cpu = ref.watch(cpuStreamProvider);
    final mem = ref.watch(memoryStreamProvider);
    final bat = ref.watch(batteryStreamProvider);
    final thermal = ref.watch(sectionMetadataStreamProvider('thermal'));
    final prefs = ref
        .watch(unitPreferencesStreamProvider)
        .maybeWhen(data: (p) => p, orElse: () => UnitPreferences.defaults);
    final formatter = ref.watch(unitsFormatterProvider);
    final theme = Theme.of(context);
    final tokens = theme.extension<ThemeTokensExtension>()!.tokens;

    return Scaffold(
      appBar: AppBar(
        title: Text('nav.dashboard'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () => _exportSnapshot(context, ref),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = width >= 1100
              ? 3
              : width >= 700
              ? 2
              : 1;

          return ListView(
            padding: EdgeInsets.all(tokens.space2),
            children: [
              AppSection(
                title: 'dashboard.liveTitle'.tr,
                subtitle: 'dashboard.liveSubtitle'.tr,
                child: GridView.count(
                  crossAxisCount: columns,
                  crossAxisSpacing: tokens.space3,
                  mainAxisSpacing: tokens.space3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: columns == 1 ? 3.2 : 2.4,
                  children: [
                    _MetricTile(
                      title: 'nav.cpu'.tr,
                      icon: Icons.speed,
                      value: cpu.when(
                        data: (v) =>
                            '${v.usage.toWholePercent()}% · ${v.cores} cores',
                        loading: () => 'availability.loading'.tr,
                        error: (err, st) => 'availability.unavailable'.tr,
                      ),
                      onTap: () => context.go('/testers/cpu'),
                    ),
                    _MetricTile(
                      title: 'nav.memory'.tr,
                      icon: Icons.memory,
                      value: mem.when(
                        data: (m) =>
                            '${(m.usedRatio * 100).toStringAsFixed(1)}%',
                        loading: () => 'availability.loading'.tr,
                        error: (err, st) => 'availability.unavailable'.tr,
                      ),
                      onTap: () => context.go('/info/memory-storage'),
                    ),
                    _MetricTile(
                      title: 'nav.battery'.tr,
                      icon: Icons.battery_std,
                      value: bat.when(
                        data: (b) => '${b.percent}%',
                        loading: () => 'availability.loading'.tr,
                        error: (err, st) => 'availability.unavailable'.tr,
                      ),
                      onTap: () => context.go('/testers/battery'),
                    ),
                    _MetricTile(
                      title: 'section.thermal'.tr,
                      icon: Icons.thermostat,
                      value: thermal.when(
                        data: (v) =>
                            _thermalSummary(
                              v,
                              prefs: prefs,
                              formatter: formatter,
                            ) ??
                            'availability.unavailable'.tr,
                        loading: () => 'availability.loading'.tr,
                        error: (err, st) => 'availability.unavailable'.tr,
                      ),
                      onTap: () => context.go('/info/thermal'),
                    ),
                  ],
                ),
              ),
              SizedBox(height: tokens.space1),
              AppSection(
                title: 'dashboard.exploreTitle'.tr,
                subtitle: 'dashboard.browseSections'.tr,
                trailing: TextButton(
                  onPressed: () => context.go('/info'),
                  child: Text('action.open'.tr),
                ),
                child: AppCard(
                  padding: EdgeInsets.all(tokens.space2),
                  child: Wrap(
                    spacing: tokens.space2,
                    runSpacing: tokens.space2,
                    children: [
                      for (final def in sectionDefinitions)
                        ActionChip(
                          avatar: Icon(def.icon, size: 18),
                          label: Text(def.titleKey.tr),
                          onPressed: () =>
                              context.go('/info/${def.pathSegment}'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportSnapshot(BuildContext context, WidgetRef ref) async {
    final format = await showExportFormatSheet(context);
    if (format == null) return;

    final result = await ref
        .read(androidSystemDatasourceProvider)
        .exportInputsSnapshotResult(
          includeLastKnownSensors: true,
          maxSensorSamples: 128,
        );
    if (result['ok'] != true) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('availability.unavailable'.tr)));
      }
      return;
    }

    final data = result['data'];
    final map = data is Map
        ? data.cast<String, dynamic>()
        : <String, dynamic>{};
    final service = ref.read(exportServiceProvider);
    final file = await service.exportSnapshot(
      map,
      format: format,
      fileBaseName: 'fidel-snapshot',
    );
    await service.share(file);
  }

  String? _thermalSummary(
    InfoSectionEntity section, {
    required UnitPreferences prefs,
    required UnitsFormatter formatter,
  }) {
    final tempsJson = _findText(section, 'thermal.temperatures');
    if (tempsJson != null && tempsJson.isNotEmpty) {
      final max = _maxTempCFromJson(tempsJson);
      if (max != null) {
        return formatter.formatTemperature(
          celsius: max,
          unit: prefs.temperature,
        );
      }
    }
    return _findText(section, 'thermal.thermalStatus');
  }

  String? _findText(InfoSectionEntity section, String labelKey) {
    for (final item in section.items) {
      if (item.labelKey != labelKey) continue;
      return item.value?.text;
    }
    return null;
  }

  double? _maxTempCFromJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      final items = switch (decoded) {
        List list => list.whereType<Map>().map(
          (entry) => entry.cast<String, dynamic>(),
        ),
        Map map => map.entries.map((entry) {
          final value = entry.value;
          if (value is Map) return value.cast<String, dynamic>();
          return <String, dynamic>{'name': entry.key, 'valueC': value};
        }),
        _ => const Iterable<Map<String, dynamic>>.empty(),
      };
      double? max;
      for (final map in items) {
        final value =
            map['valueC'] ?? map['value'] ?? map['tempC'] ?? map['celsius'];
        final numValue = switch (value) {
          num v => v.toDouble(),
          String v => double.tryParse(v),
          _ => null,
        };
        if (numValue == null || numValue.isNaN || numValue.isInfinite) continue;
        max = max == null ? numValue : (numValue > max ? numValue : max);
      }
      return max;
    } catch (_) {
      return null;
    }
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.title,
    required this.icon,
    required this.value,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<ThemeTokensExtension>()!.tokens;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(tokens.radiusMd),
            ),
            child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
          ),
          SizedBox(width: tokens.space3),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: tokens.space1 / 2),
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
