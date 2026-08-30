import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/system_providers.dart';
import '../../../application/providers/units_providers.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_page_scaffold.dart';
import '../../../core/ui/async_value_view.dart';
import '../../../core/ui/glass_card.dart';
import '../../../core/ui/ring_gauge.dart';
import '../../../core/ui/severity_chip.dart';
import '../../../core/ui/spec_row.dart';
import '../../../core/ui/sparkline.dart';
import '../../../domain/entities/battery_entity.dart';
import '../../../domain/units/measurement_formatter.dart';
import '../../../domain/units/unit_preferences.dart';
import '../../../domain/units/units_formatter.dart';

class BatteryMonitorPage extends ConsumerStatefulWidget {
  const BatteryMonitorPage({super.key});

  @override
  ConsumerState<BatteryMonitorPage> createState() => _BatteryMonitorPageState();
}

class _BatteryMonitorPageState extends ConsumerState<BatteryMonitorPage> {
  static const _maxSamples = 120;
  final List<double> _percentHistory = [];
  final List<double> _powerHistory = [];

  void _onEvent(AsyncValue<BatteryEntity> next) {
    final b = next.value;
    if (b == null) return;
    setState(() {
      _percentHistory.add(b.percent.toDouble());
      if (_percentHistory.length > _maxSamples) _percentHistory.removeAt(0);
      if (b.watts != null && b.watts!.isFinite) {
        _powerHistory.add(b.watts!);
        if (_powerHistory.length > _maxSamples) _powerHistory.removeAt(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(batteryStreamProvider, (_, next) => _onEvent(next));
    final prefs = ref.watch(unitPreferencesStreamProvider).value ??
        UnitPreferences.defaults;
    final formatter = ref.watch(unitsFormatterProvider);

    return AppPageScaffold(
      title: 'testers.batteryMonitor'.tr,
      children: [
        AsyncValueView<BatteryEntity>(
          value: ref.watch(batteryStreamProvider),
          errorTitle: 'availability.unavailable'.tr,
          retryLabel: 'action.retry'.tr,
          onRetry: () => ref.invalidate(batteryStreamProvider),
          data: (battery) => _Body(
            battery: battery,
            prefs: prefs,
            formatter: formatter,
            percentHistory: _percentHistory,
            powerHistory: _powerHistory,
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.battery,
    required this.prefs,
    required this.formatter,
    required this.percentHistory,
    required this.powerHistory,
  });

  final BatteryEntity battery;
  final UnitPreferences prefs;
  final UnitsFormatter formatter;
  final List<double> percentHistory;
  final List<double> powerHistory;

  SeverityLevel get _level {
    if (battery.status == 'full') return SeverityLevel.success;
    if (battery.charging == true || battery.status == 'charging') {
      return SeverityLevel.success;
    }
    if (battery.percent < 15) return SeverityLevel.danger;
    if (battery.percent < 30) return SeverityLevel.warning;
    return SeverityLevel.info;
  }

  IconData _plugIcon() => switch (battery.plugSource) {
        'usb' => Icons.usb,
        'wireless' => Icons.wifi_tethering,
        'dock' => Icons.dock,
        'ac' => Icons.electrical_services,
        _ => Icons.power,
      };

  String? _statusLabel() {
    final status = battery.status;
    if (status == null || status.isEmpty) return null;
    return 'battery.status.$status'.tr;
  }

  String? _plugLabel() {
    final source = battery.plugSource;
    if (source == null || source.isEmpty) return null;
    return 'battery.plug.$source'.tr;
  }

  String? _healthLabel() {
    final health = battery.health;
    if (health == null || health.isEmpty) return null;
    switch (health) {
      case 'good':
        return 'battery.health.good'.tr;
      case 'overheat':
        return 'battery.health.overheat'.tr;
      case 'dead':
        return 'battery.health.dead'.tr;
      case 'over_voltage':
        return 'battery.health.over_voltage'.tr;
      case 'cold':
        return 'battery.health.cold'.tr;
      case 'unspecified_failure':
        return 'battery.health.unspecified_failure'.tr;
      default:
        return health;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    final gaugeColor = switch (_level) {
      SeverityLevel.success => tokens.successColor,
      SeverityLevel.warning => tokens.warningColor,
      SeverityLevel.danger => tokens.dangerColor,
      SeverityLevel.info => null,
    };
    final pct = battery.percent.clamp(0, 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            RingGauge(
              value: pct / 100,
              size: 168,
              strokeWidth: 13,
              gradientStroke: gaugeColor == null,
              progressColor: gaugeColor,
              child: Text(
                '$pct%',
                style: AppText.heroNumeric(context, color: gaugeColor),
              ),
            ),
            SizedBox(width: tokens.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SeverityChip(
                    level: _level,
                    label: _statusLabel() ?? 'battery.status.unknown'.tr,
                  ),
                  SizedBox(height: tokens.space2),
                  if (_plugLabel() != null)
                    Row(
                      children: [
                        Icon(
                          _plugIcon(),
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        SizedBox(width: tokens.space1),
                        Flexible(
                          child: Text(
                            _plugLabel()!,
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (battery.watts != null) ...[
                    SizedBox(height: tokens.space1),
                    Text(
                      formatMeasurement(battery.watts, unit: 'W'),
                      style: AppText.numeric(
                        context,
                        color: (battery.watts ?? 0) > 0
                            ? tokens.successColor
                            : null,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.space3),
        _TrendCard(
          title: 'battery.percentHistory'.tr,
          data: percentHistory,
          color: gaugeColor ?? theme.colorScheme.primary,
        ),
        if (powerHistory.isNotEmpty) ...[
          SizedBox(height: tokens.space2),
          _TrendCard(
            title: 'battery.powerHistory'.tr,
            data: powerHistory,
            color: theme.colorScheme.primary,
          ),
        ],
        SizedBox(height: tokens.space3),
        GlassCard(
          padding: EdgeInsets.all(tokens.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('battery.vitals'.tr, style: theme.textTheme.titleMedium),
              SizedBox(height: tokens.space1),
              SpecRow(
                label: 'battery.voltage'.tr,
                numeric: true,
                value: formatMeasurement(battery.voltageV, unit: 'V'),
              ),
              SpecRow(
                label: 'battery.currentNowUa'.tr,
                numeric: true,
                value: battery.currentMicroAmps == null
                    ? '—'
                    : formatter.formatElectricCurrent(
                        microAmps: battery.currentMicroAmps!,
                      ),
              ),
              SpecRow(
                label: 'battery.currentEstimated'.tr,
                numeric: true,
                value: battery.estimatedCurrentMicroAmps == null
                    ? null
                    : '~${formatter.formatElectricCurrent(microAmps: battery.estimatedCurrentMicroAmps!.toDouble())}',
              ),
              SpecRow(
                label: 'battery.currentAverageUa'.tr,
                numeric: true,
                value: battery.averageCurrentMicroAmps == null
                    ? '—'
                    : formatter.formatElectricCurrent(
                        microAmps:
                            battery.averageCurrentMicroAmps!.toDouble(),
                      ),
              ),
              SpecRow(
                label: 'battery.chargingPower'.tr,
                numeric: true,
                value: formatMeasurement(battery.watts, unit: 'W'),
              ),
              SpecRow(
                label: 'battery.temperature'.tr,
                numeric: true,
                value: battery.temperatureC == null ||
                        battery.temperatureC! < -40
                    ? '—'
                    : formatter.formatTemperature(
                        celsius: battery.temperatureC!,
                        unit: prefs.temperature,
                      ),
              ),
              SpecRow(
                label: 'battery.capacity'.tr,
                numeric: true,
                value: formatMeasurement(battery.capacityMah, unit: 'mAh'),
              ),
              SpecRow(
                label: 'battery.chargeRemaining'.tr,
                numeric: true,
                value: battery.chargeCounterUah == null
                    ? null
                    : formatMeasurement(
                        battery.chargeCounterUah! / 1000.0,
                        unit: 'mAh',
                      ),
              ),
              SpecRow(
                label: 'battery.energyCounterMwh'.tr,
                numeric: true,
                value: battery.energyCounterNwh == null
                    ? null
                    : formatMeasurement(
                        battery.energyCounterNwh! / 1000.0,
                        unit: 'mWh',
                      ),
              ),
              SpecRow(label: 'battery.status'.tr, value: _statusLabel()),
              SpecRow(label: 'battery.plugged'.tr, value: _plugLabel()),
              SpecRow(label: 'battery.health'.tr, value: _healthLabel()),
            ],
          ),
        ),
        SizedBox(height: tokens.space1),
      ],
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.title,
    required this.data,
    required this.color,
  });

  final String title;
  final List<double> data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (data.isEmpty) return const SizedBox.shrink();
    return GlassCard(
      padding: EdgeInsets.all(tokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: AppText.muted(context)),
              ),
              Text(
                data.last.toStringAsFixed(data.last.abs() >= 10 ? 0 : 1),
                style: AppText.numeric(context, color: color),
              ),
            ],
          ),
          SizedBox(height: tokens.space1),
          SizedBox(
            height: tokens.space4 + tokens.space2,
            width: double.infinity,
            child: Sparkline(data: data, color: color),
          ),
        ],
      ),
    );
  }
}
