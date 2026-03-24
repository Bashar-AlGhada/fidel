import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/export_providers.dart';
import '../../../application/providers/system_providers.dart';
import '../../../application/sampling/active_module.dart';
import '../../../application/sampling/sampling_provider.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_states.dart';
import '../../../domain/entities/sensors/sensor_entity.dart';
import '../../../domain/entities/sensors/sensor_reading_entity.dart';
import '../../../features/export/presentation/export_format_sheet.dart';
import 'widgets/sensor_chart.dart';

class SensorDetailPage extends ConsumerStatefulWidget {
  const SensorDetailPage({required this.sensorKey, super.key});

  final String sensorKey;

  @override
  ConsumerState<SensorDetailPage> createState() => _SensorDetailPageState();
}

class _SensorDetailPageState extends ConsumerState<SensorDetailPage> {
  int _samplingPeriodUs = 200000;
  int _maxSamples = 128;

  @override
  Widget build(BuildContext context) {
    final activeModule = ref.watch(activeModuleProvider);
    if (activeModule != ActiveModule.info) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(activeModuleProvider.notifier).setModule(ActiveModule.info);
      });
    }

    final sensorsAsync = ref.watch(
      sensorsStreamProvider((
        samplingPeriodUs: _samplingPeriodUs,
        maxSamples: _maxSamples,
      )),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('sensor.detailTitle'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () => _export(context, sensorsAsync.asData?.value),
          ),
        ],
      ),
      body: sensorsAsync.when(
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
          actionLabel: 'action.retry'.tr,
          onAction: () => ref.invalidate(
            sensorsStreamProvider((
              samplingPeriodUs: _samplingPeriodUs,
              maxSamples: _maxSamples,
            )),
          ),
        ),
      ),
    );
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

    final format = await showExportFormatSheet(context);
    if (format == null) return;

    final service = ref.read(exportServiceProvider);
    final file = await service.exportSensors(
      [sensor],
      format: format,
      fileBaseName: 'fidel-sensor',
    );
    await service.share(file);
  }

  Widget _buildLoaded(BuildContext context, SensorEntity sensor) {
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
            subtitle: Text('${cap.vendor} • type ${cap.type}'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'sensors.controls'.tr,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Text('sensors.sampling'.tr)),
                    DropdownButton<int>(
                      value: _samplingPeriodUs,
                      onChanged: (v) => v == null
                          ? null
                          : setState(() => _samplingPeriodUs = v),
                      items: const [
                        DropdownMenuItem(value: 50000, child: Text('50ms')),
                        DropdownMenuItem(value: 100000, child: Text('100ms')),
                        DropdownMenuItem(value: 200000, child: Text('200ms')),
                        DropdownMenuItem(value: 500000, child: Text('500ms')),
                        DropdownMenuItem(value: 1000000, child: Text('1s')),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: Text('sensors.window'.tr)),
                    DropdownButton<int>(
                      value: _maxSamples,
                      onChanged: (v) =>
                          v == null ? null : setState(() => _maxSamples = v),
                      items: const [
                        DropdownMenuItem(value: 32, child: Text('32')),
                        DropdownMenuItem(value: 64, child: Text('64')),
                        DropdownMenuItem(value: 128, child: Text('128')),
                        DropdownMenuItem(value: 256, child: Text('256')),
                        DropdownMenuItem(value: 512, child: Text('512')),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'sensor.currentValue'.tr,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(_formatValues(latest) ?? 'availability.unavailable'.tr),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'sensor.chart'.tr,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                SensorChart(
                  samples: samples,
                  height: 180,
                  onRetry: () => ref.invalidate(
                    sensorsStreamProvider((
                      samplingPeriodUs: _samplingPeriodUs,
                      maxSamples: _maxSamples,
                    )),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'sensor.capabilities'.tr,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
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

  String? _formatValues(SensorReadingEntity? latest) {
    if (latest == null) return null;
    if (latest.values.isEmpty) return null;
    return latest.values.map((v) => v.toStringAsFixed(3)).join(', ');
  }
}
