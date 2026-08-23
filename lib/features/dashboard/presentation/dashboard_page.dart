import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/export_providers.dart';
import '../../../application/providers/system_providers.dart';
import '../../../application/providers/units_providers.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/app_section.dart';
import '../../../core/ui/layout.dart';
import '../../../domain/entities/info/info_section_entity.dart';
import '../../../domain/units/unit_preferences.dart';
import '../../../domain/units/units_formatter.dart';
import '../../../features/export/presentation/export_flow.dart';
import '../../sections/presentation/widgets/sensor_sampling_options.dart';
import '../../sections/presentation/widgets/section_items.dart';
import '../../sections/presentation/widgets/thermal_payload.dart';
import '../../sections/sections_registry.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = theme.extension<ThemeTokensExtension>()!.tokens;

    return Scaffold(
      appBar: AppBar(
        title: Text('nav.dashboard'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'action.export'.tr,
            onPressed: () => _exportSnapshot(context, ref),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = responsiveGridColumns(constraints.maxWidth);

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
                  childAspectRatio: responsiveGridChildAspectRatio(columns),
                  children: const [
                    _CpuMetricTile(),
                    _MemoryMetricTile(),
                    _BatteryMetricTile(),
                    _ThermalMetricTile(),
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
    await runExportFlow(context, (format) async {
      final result = await ref
          .read(androidSystemDatasourceProvider)
          .exportInputsSnapshotResult(
            includeLastKnownSensors: true,
            maxSensorSamples: defaultMaxSamples,
          );
      if (result['ok'] != true) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('availability.unavailable'.tr)),
          );
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
    });
  }
}

/// Highest finite temperature of a thermal section, formatted for display.
String? _thermalSummary(
  InfoSectionEntity section, {
  required UnitPreferences prefs,
  required UnitsFormatter formatter,
}) {
  final tempsJson = findItemText(section, 'thermal.temperatures');
  if (tempsJson != null && tempsJson.isNotEmpty) {
    final max = maxTemperatureFromRaw(tempsJson);
    if (max != null) {
      return formatter.formatTemperature(celsius: max, unit: prefs.temperature);
    }
  }
  return findItemText(section, 'thermal.thermalStatus');
}

class _CpuMetricTile extends ConsumerWidget {
  const _CpuMetricTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cpu = ref.watch(cpuStreamProvider);
    return _MetricTile(
      title: 'nav.cpu'.tr,
      icon: Icons.speed,
      value: cpu.when(
        skipLoadingOnReload: true,
        data: (v) =>
            '${v.usage.toWholePercent()}% · ${'dashboard.cores'.trParams({'n': '${v.cores}'})}',
        loading: () => 'availability.loading'.tr,
        error: (err, st) => 'availability.unavailable'.tr,
      ),
      onTap: () => context.go('/testers/cpu'),
    );
  }
}

class _MemoryMetricTile extends ConsumerWidget {
  const _MemoryMetricTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mem = ref.watch(memoryStreamProvider);
    return _MetricTile(
      title: 'nav.memory'.tr,
      icon: Icons.memory,
      value: mem.when(
        skipLoadingOnReload: true,
        data: (m) => '${(m.usedRatio * 100).toStringAsFixed(1)}%',
        loading: () => 'availability.loading'.tr,
        error: (err, st) => 'availability.unavailable'.tr,
      ),
      onTap: () => context.go('/info/memory-storage'),
    );
  }
}

class _BatteryMetricTile extends ConsumerWidget {
  const _BatteryMetricTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bat = ref.watch(batteryStreamProvider);
    return _MetricTile(
      title: 'nav.battery'.tr,
      icon: Icons.battery_std,
      value: bat.when(
        skipLoadingOnReload: true,
        data: (b) => '${b.percent}%',
        loading: () => 'availability.loading'.tr,
        error: (err, st) => 'availability.unavailable'.tr,
      ),
      onTap: () => context.go('/testers/battery'),
    );
  }
}

class _ThermalMetricTile extends ConsumerWidget {
  const _ThermalMetricTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thermal = ref.watch(sectionMetadataStreamProvider('thermal'));
    final prefs = ref
        .watch(unitPreferencesStreamProvider)
        .maybeWhen(data: (p) => p, orElse: () => UnitPreferences.defaults);
    final formatter = ref.watch(unitsFormatterProvider);

    return _MetricTile(
      title: 'section.thermal'.tr,
      icon: Icons.thermostat,
      value: thermal.when(
        skipLoadingOnReload: true,
        data: (v) =>
            _thermalSummary(v, prefs: prefs, formatter: formatter) ??
            'availability.unavailable'.tr,
        loading: () => 'availability.loading'.tr,
        error: (err, st) => 'availability.unavailable'.tr,
      ),
      onTap: () => context.go('/info/thermal'),
    );
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
        ],
      ),
    );
  }
}
