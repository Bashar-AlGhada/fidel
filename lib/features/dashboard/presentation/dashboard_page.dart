import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/export_providers.dart';
import '../../../application/providers/system_providers.dart';
import '../../../application/providers/units_providers.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_section.dart';
import '../../../core/ui/glass_card.dart';
import '../../../core/ui/hero_metric_tile.dart';
import '../../../core/ui/layout.dart';
import '../../../core/ui/severity_chip.dart';
import '../../../domain/entities/info/info_section_entity.dart';
import '../../../domain/entities/memory_entity.dart';
import '../../../domain/units/measurement_formatter.dart';
import '../../../features/export/presentation/export_flow.dart';
import '../../sections/presentation/widgets/section_items.dart';
import '../../sections/presentation/widgets/sensor_sampling_options.dart'
    show defaultMaxSamples;
import '../../sections/presentation/widgets/thermal_payload.dart';
import '../../sections/presentation/widgets/thermal_severity.dart';
import '../../sections/sections_registry.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;

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
              const _StaggerIn(index: 0, child: _DeviceHeaderCard()),
              SizedBox(height: tokens.space2),
              _StaggerIn(
                index: 1,
                child: AppSection(
                  title: 'dashboard.liveTitle'.tr,
                  subtitle: 'dashboard.liveSubtitle'.tr,
                  icon: Icons.monitor_heart,
                  padding: EdgeInsets.zero,
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: tokens.space2,
                      mainAxisSpacing: tokens.space2,
                      mainAxisExtent: 156,
                    ),
                    itemCount: 4,
                    itemBuilder: (context, index) => _StaggerIn(
                      index: index + 1,
                      child: switch (index) {
                        0 => const _CpuMetricTile(),
                        1 => const _MemoryMetricTile(),
                        2 => const _BatteryMetricTile(),
                        _ => const _ThermalMetricTile(),
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(height: tokens.space2),
              _StaggerIn(
                index: 3,
                child: AppSection(
                  title: 'dashboard.exploreTitle'.tr,
                  subtitle: 'dashboard.browseSections'.tr,
                  icon: Icons.explore_outlined,
                  padding: EdgeInsets.zero,
                  trailing: TextButton(
                    onPressed: () => context.go('/info'),
                    child: Text('action.open'.tr),
                  ),
                  child: SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: sectionDefinitions.length,
                      separatorBuilder: (_, _) => SizedBox(width: tokens.space1),
                      itemBuilder: (context, index) =>
                          _QuickLink(def: sectionDefinitions[index]),
                    ),
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
      final map =
          data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};
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

/// Fade/slide entrance with a per-index delay for staggered reveals.
class _StaggerIn extends StatelessWidget {
  const _StaggerIn({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final delay = (index * 0.08).clamp(0.0, 0.56);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: tokens.motionSlow,
      curve: Interval(delay, 1, curve: Curves.easeOutCubic),
      builder: (context, t, _) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * tokens.space3),
          child: child,
        ),
      ),
    );
  }
}

/// Accent hero banner carrying the device identity.
class _DeviceHeaderCard extends ConsumerStatefulWidget {
  const _DeviceHeaderCard();

  @override
  ConsumerState<_DeviceHeaderCard> createState() => _DeviceHeaderCardState();
}

class _DeviceHeaderCardState extends ConsumerState<_DeviceHeaderCard> {
  Future<InfoSectionEntity>? _deviceBuildFuture;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    _deviceBuildFuture ??=
        ref.read(getSectionMetadataProvider)('device-build');

    return GlassCard(
      gradientTint: true,
      highlightBorder: true,
      padding: EdgeInsets.all(tokens.space3),
      onTap: () => context.go('/info/device-build'),
      child: Row(
        children: [
          Container(
            width: tokens.space4 + 14,
            height: tokens.space4 + 14,
            decoration: BoxDecoration(
              gradient: tokens.accentGradient,
              borderRadius: BorderRadius.circular(tokens.radiusMd),
            ),
            child: Icon(
              Icons.smartphone,
              size: 26,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          SizedBox(width: tokens.space3),
          Expanded(
            child: FutureBuilder<InfoSectionEntity>(
              future: _deviceBuildFuture,
              builder: (context, snap) {
                final section = snap.data;
                final model = section == null
                    ? null
                    : findItemText(section, 'device.model');

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      model == null || model.isEmpty ? 'Fidel' : model,
                      style: theme.textTheme.headlineSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: tokens.space1 / 2),
                    Text(
                      'dashboard.deviceTagline'.tr,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            ),
          ),
          SizedBox(width: tokens.space2),
          FutureBuilder<InfoSectionEntity>(
            future: _deviceBuildFuture,
            builder: (context, snap) {
              final sdk = snap.data == null
                  ? null
                  : findItemText(snap.data!, 'build.sdkInt');
              if (sdk == null || sdk.isEmpty) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: ShapeDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.7,
                  ),
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: Text('Android $sdk', style: theme.textTheme.labelMedium),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Rolling sample buffer (max 60 points) fed from stream providers.
mixin _SparkBuffer<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final List<double> samples = [];

  void pushSample(double? value) {
    if (value == null || value.isNaN || value.isInfinite) return;
    if (samples.isNotEmpty && samples.last == value) return;
    setState(() {
      samples.add(value);
      if (samples.length > 60) samples.removeAt(0);
    });
  }
}

class _CpuMetricTile extends ConsumerStatefulWidget {
  const _CpuMetricTile();

  @override
  ConsumerState<_CpuMetricTile> createState() => _CpuMetricTileState();
}

class _CpuMetricTileState extends ConsumerState<_CpuMetricTile>
    with _SparkBuffer {
  @override
  Widget build(BuildContext context) {
    ref.listen(cpuStreamProvider, (prev, next) {
      pushSample(next.asData?.value.usage.toWholePercent().toDouble());
    });
    final cpu = ref.watch(cpuStreamProvider);

    final cores = cpu.asData?.value.cores;
    final caption = cores == null
        ? null
        : 'dashboard.cores'.trParams({'n': '$cores'});

    return HeroMetricTile(
      label: captionedLabel(context, 'nav.cpu'.tr, caption),
      icon: Icons.speed,
      valueText: valueOrState(cpu, (v) => '${v.usage.toWholePercent()}%'),
      sparkline: samples,
      onTap: () => context.go('/testers/cpu'),
    );
  }
}

class _MemoryMetricTile extends ConsumerStatefulWidget {
  const _MemoryMetricTile();

  @override
  ConsumerState<_MemoryMetricTile> createState() => _MemoryMetricTileState();
}

class _MemoryMetricTileState extends ConsumerState<_MemoryMetricTile>
    with _SparkBuffer {
  @override
  Widget build(BuildContext context) {
    ref.listen(memoryStreamProvider, (prev, next) {
      final m = next.asData?.value;
      if (m != null) pushSample(m.usedRatio * 100);
    });
    final mem = ref.watch(memoryStreamProvider);

    return HeroMetricTile(
      label: captionedLabel(context, 'nav.memory'.tr, _sizeCaption(mem)),
      icon: Icons.memory,
      valueText: valueOrState(mem, (m) => '${(m.usedRatio * 100).toStringAsFixed(0)}%'),
      sparkline: samples,
      onTap: () => context.go('/info/memory-storage'),
    );
  }

  String? _sizeCaption(AsyncValue<MemoryEntity> mem) {
    final m = mem.asData?.value;
    if (m == null) return null;
    final prefs = ref.watch(unitPreferencesStreamProvider).asData?.value;
    if (prefs == null) return null;
    final formatter = ref.watch(unitsFormatterProvider);
    return '${formatter.formatBytes(bytes: m.usedBytes, base: prefs.dataSizeBase)}'
        ' / '
        '${formatter.formatBytes(bytes: m.totalBytes, base: prefs.dataSizeBase)}';
  }
}

class _BatteryMetricTile extends ConsumerWidget {
  const _BatteryMetricTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bat = ref.watch(batteryStreamProvider);
    final b = bat.asData?.value;
    final tokens = context.tokens;

    final charging = b?.charging ?? false;
    final color = charging
        ? tokens.successColor
        : (b != null && b.percent <= 20 ? tokens.dangerColor : null);

    String? caption;
    if (b != null) {
      final temp = b.temperatureC;
      caption = temp != null
          ? formatMeasurement(temp, unit: '°C')
          : (b.status ?? '');
    }

    return HeroMetricTile(
      label: captionedLabel(context, 'nav.battery'.tr, caption),
      icon: charging ? Icons.battery_charging_full : Icons.battery_std,
      valueText: b == null
          ? asyncStateText(bat)
          : '${b.percent}%',
      valueColor: color,
      onTap: () => context.go('/testers/battery'),
    );
  }
}

class _ThermalMetricTile extends ConsumerStatefulWidget {
  const _ThermalMetricTile();

  @override
  ConsumerState<_ThermalMetricTile> createState() => _ThermalMetricTileState();
}

class _ThermalSnapshot {
  const _ThermalSnapshot({this.maxTemp, this.zoneName, this.statusWord});

  final double? maxTemp;
  final String? zoneName;
  final String? statusWord;
}

class _ThermalMetricTileState extends ConsumerState<_ThermalMetricTile> {
  InfoSectionEntity? _parsedSource;
  _ThermalSnapshot _snapshot = const _ThermalSnapshot();

  _ThermalSnapshot _parse(InfoSectionEntity section) {
    // Structured zones ({name,type,valueC}) carry zone names; legacy
    // temperatures are the fallback source.
    double? maxTemp;
    String? zoneName;
    final zonesJson = findItemText(section, 'thermal.zones');
    if (zonesJson != null && zonesJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(zonesJson);
        if (decoded is List) {
          for (final entry in decoded.whereType<Map>()) {
            final raw = entry['valueC'] ?? entry['tempC'];
            final v = raw is num ? raw.toDouble() : double.tryParse('$raw');
            if (v == null || !v.isFinite) continue;
            if (maxTemp == null || v >= maxTemp) {
              maxTemp = v;
              zoneName = entry['name']?.toString();
            }
          }
        }
      } catch (e, st) {
        AppLog.warn('Failed to parse thermal zones', error: e, stackTrace: st);
      }
    }

    maxTemp ??= maxTemperatureFromRaw(
      findItemText(section, 'thermal.temperatures') ?? '',
    );

    return _ThermalSnapshot(
      maxTemp: maxTemp,
      zoneName: zoneName,
      statusWord: findItemText(section, 'thermal.thermalStatusLabel'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final thermal = ref.watch(sectionMetadataStreamProvider('thermal'));
    final prefs = ref
        .watch(unitPreferencesStreamProvider)
        .maybeWhen(data: (p) => p, orElse: () => null);
    final formatter = ref.watch(unitsFormatterProvider);

    final section = thermal.asData?.value;
    if (section != null && !identical(_parsedSource, section)) {
      _parsedSource = section;
      _snapshot = _parse(section);
    }

    final tokens = context.tokens;
    final word = _snapshot.statusWord;
    final level = thermalSeverityForWord(word);
    final tempText = _snapshot.maxTemp == null || prefs == null
        ? null
        : formatter.formatTemperature(
            celsius: _snapshot.maxTemp!,
            unit: prefs.temperature,
          );

    final valueText = tempText ??
        (word == null ? null : thermalStatusLabel(word)) ??
        asyncStateText(thermal);

    return Stack(
      children: [
        HeroMetricTile(
          label: captionedLabel(
            context,
            'section.thermal'.tr,
            _snapshot.zoneName ?? (tempText != null ? 'thermal.currentStatus'.tr : null),
          ),
          icon: Icons.thermostat,
          valueText: valueText,
          valueColor: tempText == null ? null : thermalTokenColor(context, level),
          onTap: () => context.go('/info/thermal'),
        ),
        if (word != null)
          Positioned(
            top: tokens.space2,
            right: tokens.space2,
            child: SeverityChip(
              level: level,
              dot: false,
              label: thermalStatusLabel(word),
            ),
          ),
      ],
    );
  }
}

/// Joins a tile title with its muted context caption (`Title • caption`).
String captionedLabel(BuildContext context, String title, String? caption) =>
    caption == null || caption.isEmpty ? title : '$title • $caption';

String valueOrState<T>(AsyncValue<T> value, String Function(T) render) =>
    value.asData == null ? asyncStateText(value) : render(value.asData!.value);

String asyncStateText<T>(AsyncValue<T> value) =>
    value.isLoading && value.asData == null
        ? 'availability.loading'.tr
        : 'availability.unavailable'.tr;

/// Compact horizontal quick-link into a metadata section.
class _QuickLink extends StatelessWidget {
  const _QuickLink({required this.def});

  final SectionDefinition def;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Material(
      color: theme.colorScheme.surfaceContainer,
      shape: StadiumBorder(
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => context.go('/info/${def.pathSegment}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(def.icon, size: 16, color: theme.colorScheme.primary),
              SizedBox(width: tokens.space1 / 2 + 2),
              Text(def.titleKey.tr, style: theme.textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}
