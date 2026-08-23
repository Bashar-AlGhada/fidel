import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/export_providers.dart';
import '../../../application/providers/system_providers.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_states.dart';
import '../../../domain/entities/sensors/sensor_entity.dart';
import '../../../domain/entities/sensors/sensor_reading_entity.dart';
import '../../../features/export/presentation/export_flow.dart';
import 'widgets/sensor_chart.dart';
import 'widgets/sensor_controls_card.dart';

class SensorDetailPage extends ConsumerStatefulWidget {
  const SensorDetailPage({required this.sensorKey, super.key});

  final String sensorKey;

  @override
  ConsumerState<SensorDetailPage> createState() => _SensorDetailPageState();
}

class _SensorDetailPageState extends ConsumerState<SensorDetailPage> {
  @override
  Widget build(BuildContext context) {
    final sensorsAsync = ref.watch(
      sensorsStreamProvider(ref.watch(sensorsConfigProvider)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_sensorDisplayName(sensorsAsync)),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'action.export'.tr,
            onPressed: () => _export(context, sensorsAsync.asData?.value),
          ),
        ],
      ),
      body: sensorsAsync.when(
        skipLoadingOnReload: true,
        data: (sensors) {
          final sensor = sensors.cast<SensorEntity?>().firstWhere(
            (s) => s?.capability.key == widget.sensorKey,
            orElse: () => null,
          );
          if (sensor == null) {
            return AppEmptyState(
              title: 'availability.notSupported'.tr,
              message: 'sensor.noDataHint'.tr,
              icon: Icons.sensors_off_outlined,
            );
          }
          return _buildLoaded(context, sensor);
        },
        loading: () => const AppLoadingState(),
        error: (err, st) => AppErrorState(
          title: 'availability.unavailable'.tr,
          message: '$err',
          actionLabel: 'action.retry'.tr,
          onAction: () => ref.invalidate(
            sensorsStreamProvider(ref.watch(sensorsConfigProvider)),
          ),
        ),
      ),
    );
  }

  /// Shows the concrete sensor in the app bar / task switcher as soon as
  /// it is known, instead of a generic "Sensor" label.
  String _sensorDisplayName(AsyncValue<List<SensorEntity>> sensorsAsync) {
    final sensor = sensorsAsync.asData?.value.cast<SensorEntity?>().firstWhere(
      (s) => s?.capability.key == widget.sensorKey,
      orElse: () => null,
    );
    final cap = sensor?.capability;
    if (cap == null) return 'sensor.detailTitle'.tr;
    return cap.name.isEmpty ? cap.key : cap.name;
  }

  Future<void> _export(
    BuildContext context,
    List<SensorEntity>? sensors,
  ) async {
    final sensor = sensors?.cast<SensorEntity?>().firstWhere(
      (s) => s?.capability.key == widget.sensorKey,
      orElse: () => null,
    );
    if (sensor == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('availability.unavailable'.tr)));
      return;
    }

    final service = ref.read(exportServiceProvider);
    await runExportFlow(context, (format) async {
      final file = await service.exportSensors(
        [sensor],
        format: format,
        fileBaseName: 'fidel-sensor',
      );
      await service.share(file);
    });
  }

  Widget _buildLoaded(BuildContext context, SensorEntity sensor) {
    final config = ref.watch(sensorsConfigProvider);
    final tokens = Theme.of(context).extension<ThemeTokensExtension>()!.tokens;
    final cap = sensor.capability;
    final samples = sensor.samples.samples;
    final latest = samples.isEmpty ? null : samples.last;

    return ListView(
      padding: EdgeInsets.all(tokens.space3),
      children: [
        Card(
          child: ListTile(
            title: Text(cap.name.isEmpty ? cap.key : cap.name),
            subtitle: Text(
              '${cap.vendor} • ${'sensor.typeWord'.tr} ${cap.type}',
            ),
          ),
        ),
        SizedBox(height: tokens.space2),
        SensorControlsCard(
          samplingPeriodUs: config.samplingPeriodUs,
          maxSamples: config.maxSamples,
          onSamplingChanged: (v) => ref
              .read(sensorsConfigProvider.notifier)
              .update(samplingPeriodUs: v),
          onMaxSamplesChanged: (v) =>
              ref.read(sensorsConfigProvider.notifier).update(maxSamples: v),
        ),
        SizedBox(height: tokens.space2),
        Card(
          child: Padding(
            padding: EdgeInsets.all(tokens.space2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'sensor.currentValue'.tr,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: tokens.space1),
                Text(_formatValues(latest) ?? 'availability.unavailable'.tr),
                if (_climbRateMs(samples, sensor.capability.type)
                    case final climb?) ...[
                  SizedBox(height: tokens.space1),
                  Text(
                    '${'sensor.climbRate'.tr}: '
                    '${climb >= 0 ? '+' : ''}${climb.toStringAsFixed(2)} m/s',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: tokens.space2),
        Card(
          child: Padding(
            padding: EdgeInsets.all(tokens.space2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'sensor.chart'.tr,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: tokens.space2),
                SensorChart(
                  samples: samples,
                  height: 180,
                  onRetry: () => ref.invalidate(sensorsStreamProvider(config)),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: tokens.space2),
        Card(
          child: Padding(
            padding: EdgeInsets.all(tokens.space2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'sensor.capabilities'.tr,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: tokens.space1),
                Text('${'sensor.maxRange'.tr}: ${cap.maxRange}'),
                Text('${'sensor.resolution'.tr}: ${cap.resolution}'),
                Text('${'sensor.power'.tr}: ${cap.powerMilliAmp} mA'),
                Text(
                  '${'sensor.minDelay'.tr}: ${cap.minDelay.inMicroseconds} µs',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Vertical velocity from the barometric pressure sensor (type 6),
  /// derived from the last two samples via the barometric formula.
  double? _climbRateMs(List<SensorReadingEntity> samples, int sensorType) {
    if (sensorType != 6) return null;
    if (samples.length < 2) return null;
    final a = samples[samples.length - 2];
    final b = samples.last;
    if (a.values.isEmpty ||
        b.values.isEmpty ||
        !a.values.first.isFinite ||
        !b.values.first.isFinite) {
      return null;
    }
    const p0 = 1013.25;
    double alt(double hPa) =>
        44330 * (1 - math.pow(hPa / p0, 0.190294)).toDouble();
    final dh = alt(b.values.first) - alt(a.values.first);
    final dtMs = b.timestamp.difference(a.timestamp).inMilliseconds;
    if (dtMs <= 0) return null;
    return dh * 1000 / dtMs;
  }

  String? _formatValues(SensorReadingEntity? latest) {
    if (latest == null) return null;
    if (latest.values.isEmpty) return null;
    return latest.values.map((v) => v.toStringAsFixed(3)).join(', ');
  }
}
