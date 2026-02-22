import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/export_providers.dart';
import '../../../application/providers/system_providers.dart';
import '../../../application/sampling/active_module.dart';
import '../../../application/sampling/sampling_provider.dart';
import '../../../domain/entities/sensors/sensor_entity.dart';
import '../../../features/export/presentation/export_format_sheet.dart';

class SensorsSectionPage extends ConsumerStatefulWidget {
  const SensorsSectionPage({super.key});

  @override
  ConsumerState<SensorsSectionPage> createState() => _SensorsSectionPageState();
}

class _SensorsSectionPageState extends ConsumerState<SensorsSectionPage> {
  int _samplingPeriodUs = 200000;
  int _maxSamples = 128;
  String _query = '';

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
        title: Text('section.sensors'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () =>
                _exportSensors(context, sensorsAsync.asData?.value),
          ),
        ],
      ),
      body: sensorsAsync.when(
        data: (sensors) {
          final filtered = _filterSensors(sensors, _query);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ControlsCard(
                samplingPeriodUs: _samplingPeriodUs,
                maxSamples: _maxSamples,
                onSamplingChanged: (v) => setState(() => _samplingPeriodUs = v),
                onMaxSamplesChanged: (v) => setState(() => _maxSamples = v),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'search.hintSensors'.tr,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              if (sensors.isEmpty && _query.trim().isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('sensors.noSensors'.tr),
                  ),
                )
              else if (filtered.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('search.noResults'.tr),
                  ),
                )
              else
                ...filtered.map(
                  (sensor) => _SensorTile(
                    sensor: sensor,
                    onTap: () {
                      final encoded = Uri.encodeComponent(
                        sensor.capability.key,
                      );
                      context.go('/sections/sensors/$encoded');
                    },
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('availability.unavailable'.tr)),
      ),
    );
  }

  Future<void> _exportSensors(
    BuildContext context,
    List<SensorEntity>? sensors,
  ) async {
    if (sensors == null || sensors.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('availability.unavailable'.tr)));
      return;
    }

    final filtered = _filterSensors(sensors, _query);
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('search.noResults'.tr)));
      return;
    }

    final format = await showExportFormatSheet(context);
    if (format == null) return;

    final service = ref.read(exportServiceProvider);
    final file = await service.exportSensors(
      filtered,
      format: format,
      fileBaseName: 'fidel-sensors',
    );
    await service.share(file);
  }

  List<SensorEntity> _filterSensors(List<SensorEntity> sensors, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return sensors;
    return sensors
        .where((s) {
          final cap = s.capability;
          final text = '${cap.name} ${cap.vendor} ${cap.type} ${cap.key}'
              .toLowerCase();
          return text.contains(q);
        })
        .toList(growable: false);
  }
}

class _ControlsCard extends StatelessWidget {
  const _ControlsCard({
    required this.samplingPeriodUs,
    required this.maxSamples,
    required this.onSamplingChanged,
    required this.onMaxSamplesChanged,
  });

  final int samplingPeriodUs;
  final int maxSamples;
  final ValueChanged<int> onSamplingChanged;
  final ValueChanged<int> onMaxSamplesChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
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
                  value: samplingPeriodUs,
                  onChanged: (v) => v == null ? null : onSamplingChanged(v),
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
                  value: maxSamples,
                  onChanged: (v) => v == null ? null : onMaxSamplesChanged(v),
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
    );
  }
}

class _SensorTile extends StatelessWidget {
  const _SensorTile({required this.sensor, required this.onTap});

  final SensorEntity sensor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cap = sensor.capability;
    final latest = sensor.samples.samples.isEmpty
        ? null
        : sensor.samples.samples.last;
    final latestText = latest == null || latest.values.isEmpty
        ? 'availability.unavailable'.tr
        : latest.values.map((v) => v.toStringAsFixed(2)).join(', ');

    return Card(
      child: ListTile(
        leading: const Icon(Icons.sensors),
        title: Text(cap.name.isEmpty ? cap.key : cap.name),
        subtitle: Text('${cap.vendor} • type ${cap.type}'),
        trailing: Text(latestText, textAlign: TextAlign.end),
        onTap: onTap,
      ),
    );
  }
}
