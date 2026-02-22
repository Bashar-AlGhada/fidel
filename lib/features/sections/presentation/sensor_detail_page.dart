import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/export_providers.dart';
import '../../../application/providers/system_providers.dart';
import '../../../application/sampling/active_module.dart';
import '../../../application/sampling/sampling_provider.dart';
import '../../../domain/entities/sensors/sensor_entity.dart';
import '../../../domain/entities/sensors/sensor_reading_entity.dart';
import '../../../features/export/presentation/export_format_sheet.dart';

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
    if (activeModule != ActiveModule.dashboard) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(activeModuleProvider.notifier)
            .setModule(ActiveModule.dashboard);
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
            return Center(child: Text('availability.notSupported'.tr));
          }
          return _buildLoaded(context, sensor);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('availability.unavailable'.tr)),
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
    final cap = sensor.capability;
    final samples = sensor.samples.samples;
    final latest = samples.isEmpty ? null : samples.last;

    return ListView(
      padding: const EdgeInsets.all(16),
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
                SizedBox(height: 160, child: _SensorChart(samples: samples)),
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

class _SensorChart extends StatelessWidget {
  const _SensorChart({required this.samples});

  final List<SensorReadingEntity> samples;

  @override
  Widget build(BuildContext context) {
    if (samples.length < 2) {
      return Center(child: Text('sensor.notEnoughSamples'.tr));
    }
    return CustomPaint(
      painter: _SensorChartPainter(
        samples: samples,
        colorScheme: Theme.of(context).colorScheme,
      ),
    );
  }
}

class _SensorChartPainter extends CustomPainter {
  _SensorChartPainter({required this.samples, required this.colorScheme});

  final List<SensorReadingEntity> samples;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final paintBg = Paint()
      ..color = colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      paintBg,
    );

    final dims = samples.fold<int>(0, (p, s) => math.max(p, s.values.length));
    if (dims == 0) return;

    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (final s in samples) {
      for (final v in s.values) {
        if (v.isNaN || v.isInfinite) continue;
        if (v < minY) minY = v;
        if (v > maxY) maxY = v;
      }
    }
    if (!minY.isFinite || !maxY.isFinite) return;
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }

    final colors = <Color>[
      colorScheme.primary,
      colorScheme.tertiary,
      colorScheme.secondary,
      colorScheme.error,
    ];

    final left = 8.0;
    final top = 8.0;
    final w = size.width - 16.0;
    final h = size.height - 16.0;

    for (var dim = 0; dim < dims; dim++) {
      final linePaint = Paint()
        ..color = colors[dim % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final path = Path();
      var started = false;

      for (var i = 0; i < samples.length; i++) {
        final s = samples[i];
        if (dim >= s.values.length) continue;
        final v = s.values[dim];
        if (v.isNaN || v.isInfinite) continue;
        final x = left + (i / (samples.length - 1)) * w;
        final t = (v - minY) / (maxY - minY);
        final y = top + (1.0 - t) * h;
        if (!started) {
          path.moveTo(x, y);
          started = true;
        } else {
          path.lineTo(x, y);
        }
      }

      if (started) {
        canvas.drawPath(path, linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SensorChartPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.colorScheme != colorScheme;
  }
}
