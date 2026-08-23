import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/export_providers.dart';
import '../../../application/providers/system_providers.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_states.dart';
import '../../../domain/entities/sensors/sensor_entity.dart';
import '../../../features/export/presentation/export_flow.dart';
import 'widgets/sensor_controls_card.dart';

class SensorsSectionPage extends ConsumerStatefulWidget {
  const SensorsSectionPage({super.key});

  @override
  ConsumerState<SensorsSectionPage> createState() => _SensorsSectionPageState();
}

class _SensorsSectionPageState extends ConsumerState<SensorsSectionPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(sensorsConfigProvider);
    final sensorsAsync = ref.watch(sensorsStreamProvider(config));

    final tokens = Theme.of(context).extension<ThemeTokensExtension>()!.tokens;

    return Scaffold(
      appBar: AppBar(
        title: Text('section.sensors'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'action.export'.tr,
            onPressed: () =>
                _exportSensors(context, sensorsAsync.asData?.value),
          ),
        ],
      ),
      body: sensorsAsync.when(
        skipLoadingOnReload: true,
        data: (sensors) {
          final filtered = _filterSensors(sensors, _query);
          return ListView(
            padding: EdgeInsets.all(tokens.space3),
            children: [
              SensorControlsCard(
                samplingPeriodUs: config.samplingPeriodUs,
                maxSamples: config.maxSamples,
                onSamplingChanged: (v) => ref
                    .read(sensorsConfigProvider.notifier)
                    .update(samplingPeriodUs: v),
                onMaxSamplesChanged: (v) => ref
                    .read(sensorsConfigProvider.notifier)
                    .update(maxSamples: v),
              ),
              SizedBox(height: tokens.space3),
              SearchBar(
                hintText: 'search.hintSensors'.tr,
                onChanged: (v) => setState(() => _query = v),
                trailing: [
                  if (_query.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'action.clear'.tr,
                      onPressed: () => setState(() => _query = ''),
                    ),
                ],
              ),
              SizedBox(height: tokens.space3),
              if (sensors.isEmpty && _query.trim().isEmpty)
                AppEmptyState(
                  title: 'sensors.noSensors'.tr,
                  message: 'sensor.noDataHint'.tr,
                  icon: Icons.sensors_off_outlined,
                  actionLabel: 'action.retry'.tr,
                  onAction: () => ref.invalidate(sensorsStreamProvider(config)),
                )
              else if (filtered.isEmpty)
                AppEmptyState(
                  title: 'search.noResults'.tr,
                  icon: Icons.search_off_outlined,
                )
              else
                ...filtered.map(
                  (sensor) => _SensorTile(
                    sensor: sensor,
                    onTap: () {
                      final encoded = Uri.encodeComponent(
                        sensor.capability.key,
                      );
                      context.go('/info/sensors/$encoded');
                    },
                  ),
                ),
            ],
          );
        },
        loading: () => const AppLoadingState(),
        error: (err, st) => AppErrorState(
          title: 'availability.unavailable'.tr,
          message: '$err',
          actionLabel: 'action.retry'.tr,
          onAction: () => ref.invalidate(sensorsStreamProvider(config)),
        ),
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

    final service = ref.read(exportServiceProvider);
    await runExportFlow(context, (format) async {
      final file = await service.exportSensors(
        filtered,
        format: format,
        fileBaseName: 'fidel-sensors',
      );
      await service.share(file);
    });
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
        subtitle: Text('${cap.vendor} • ${'sensor.typeWord'.tr} ${cap.type}'),
        trailing: SizedBox(
          width: 120,
          child: Text(
            latestText,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
