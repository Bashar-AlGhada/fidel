import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/system_providers.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_meter.dart';
import '../../../core/ui/app_page_scaffold.dart';
import '../../../core/ui/async_value_view.dart';
import '../../../core/ui/glass_card.dart';
import '../../../core/ui/ring_gauge.dart';
import '../../../core/ui/sparkline.dart';
import '../../../domain/entities/cpu_entity.dart';
import '../../../domain/units/measurement_formatter.dart';

class CpuMonitorPage extends ConsumerStatefulWidget {
  const CpuMonitorPage({super.key});

  @override
  ConsumerState<CpuMonitorPage> createState() => _CpuMonitorPageState();
}

class _CpuMonitorPageState extends ConsumerState<CpuMonitorPage> {
  static const _maxSamples = 60;
  final List<double> _history = [];

  void _onEvent(AsyncValue<CpuEntity> next) {
    final cpu = next.value;
    if (cpu == null) return;
    setState(() {
      _history.add(cpu.usage.value * 100);
      if (_history.length > _maxSamples) _history.removeAt(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(cpuStreamProvider, (_, next) => _onEvent(next));
    final tokens = context.tokens;

    return AppPageScaffold(
      title: 'testers.cpuMonitor'.tr,
      children: [
        AsyncValueView<CpuEntity>(
          value: ref.watch(cpuStreamProvider),
          errorTitle: 'availability.unavailable'.tr,
          retryLabel: 'action.retry'.tr,
          onRetry: () => ref.invalidate(cpuStreamProvider),
          data: (cpu) {
            final percent = cpu.usage.toWholePercent();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: RingGauge(
                    value: cpu.usage.value,
                    size: 200,
                    strokeWidth: 14,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$percent%',
                          style: AppText.heroNumeric(context),
                        ),
                        Text('cpu.totalUsage'.tr, style: AppText.muted(context)),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: tokens.space3),
                GlassCard(
                  padding: EdgeInsets.all(tokens.space3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('cpu.history'.tr, style: AppText.muted(context)),
                      SizedBox(height: tokens.space1),
                      SizedBox(
                        height: tokens.space4 + tokens.space2,
                        width: double.infinity,
                        child: Sparkline(data: _history),
                      ),
                    ],
                  ),
                ),
                if (cpu.cores > 0) ...[
                  SizedBox(height: tokens.space3),
                  Text(
                    'cpu.perCore'.tr,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: tokens.space2),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width =
                          ((constraints.maxWidth - tokens.space2) / 2)
                              .clamp(130.0, 220.0);
                      return Wrap(
                        spacing: tokens.space2,
                        runSpacing: tokens.space2,
                        children: [
                          for (var i = 0; i < cpu.cores; i++)
                            SizedBox(
                              width: width,
                              child: _CoreCard(
                                index: i,
                                usage: _coreUsage(cpu, i),
                                freqMhz: _coreFreq(cpu, i),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
                SizedBox(height: tokens.space1),
              ],
            );
          },
        ),
      ],
    );
  }

  double _coreUsage(CpuEntity cpu, int index) =>
      index < cpu.coreUsages.length ? cpu.coreUsages[index].clamp(0.0, 1.0) : 0;

  double? _coreFreq(CpuEntity cpu, int index) => index < cpu.coreFreqsMhz.length
      ? cpu.coreFreqsMhz[index]
      : null;
}

class _CoreCard extends StatelessWidget {
  const _CoreCard({
    required this.index,
    required this.usage,
    required this.freqMhz,
  });

  final int index;
  final double usage;
  final double? freqMhz;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final percent = (usage * 100).round();

    return GlassCard(
      padding: EdgeInsets.all(tokens.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'cpu.core'.trParams({'index': '$index'}),
                  style: Theme.of(context).textTheme.labelLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$percent%',
                style: AppText.numeric(context),
              ),
            ],
          ),
          SizedBox(height: tokens.space1),
          AppMeter(value: usage, height: 6),
          SizedBox(height: tokens.space1),
          Text(
            freqMhz == null
                ? '—'
                : formatMeasurement(freqMhz, unit: 'MHz'),
            style: AppText.muted(context),
          ),
        ],
      ),
    );
  }
}
