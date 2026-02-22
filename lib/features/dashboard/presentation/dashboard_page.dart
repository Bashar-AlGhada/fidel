import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/export_providers.dart';
import '../../../application/providers/units_providers.dart';
import '../../../application/providers/system_providers.dart';
import '../../../application/sampling/active_module.dart';
import '../../../application/sampling/sampling_provider.dart';
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: Text('nav.cpu'.tr),
              subtitle: cpu.when(
                data: (v) => Text('${v.usage.toWholePercent()}% (${v.cores})'),
                loading: () => const Text('Loading…'),
                error: (err, st) => const Text('Unavailable'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/cpu'),
            ),
          ),
          Card(
            child: ListTile(
              title: Text('nav.memory'.tr),
              subtitle: mem.when(
                data: (m) => Text('${(m.usedRatio * 100).toStringAsFixed(1)}%'),
                loading: () => const Text('Loading…'),
                error: (err, st) => const Text('Unavailable'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/memory'),
            ),
          ),
          Card(
            child: ListTile(
              title: Text('nav.battery'.tr),
              subtitle: bat.when(
                data: (b) => Text('${b.percent}%'),
                loading: () => const Text('Loading…'),
                error: (err, st) => const Text('Unavailable'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/battery'),
            ),
          ),
          Card(
            child: ListTile(
              title: Text('section.thermal'.tr),
              subtitle: thermal.when(
                data: (v) => Text(
                  _thermalSummary(v, prefs: prefs, formatter: formatter) ??
                      'availability.unavailable'.tr,
                ),
                loading: () => Text('availability.loading'.tr),
                error: (err, st) => Text('availability.unavailable'.tr),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/sections/thermal'),
            ),
          ),
          Card(
            child: ListTile(
              title: Text('nav.sections'.tr),
              subtitle: Text('dashboard.browseSections'.tr),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/sections'),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final def in sectionDefinitions)
                    ActionChip(
                      avatar: Icon(def.icon, size: 18),
                      label: Text(def.titleKey.tr),
                      onPressed: () =>
                          context.go('/sections/${def.pathSegment}'),
                    ),
                ],
              ),
            ),
          ),
        ],
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
      if (decoded is! List) return null;
      double? max;
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final map = entry.cast<String, dynamic>();
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
