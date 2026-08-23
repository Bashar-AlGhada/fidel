import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/units_providers.dart';
import '../../../application/providers/system_providers.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_meter.dart';
import '../../../core/ui/app_states.dart';
import '../../sections/presentation/widgets/section_cards.dart';
import '../../../domain/entities/battery_entity.dart';
import '../../../domain/units/units_formatter.dart';
import '../../../domain/units/unit_preferences.dart';

class BatteryMonitorPage extends ConsumerWidget {
  const BatteryMonitorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final battery = ref.watch(batteryStreamProvider);
    final prefs = ref
        .watch(unitPreferencesStreamProvider)
        .maybeWhen(data: (p) => p, orElse: () => UnitPreferences.defaults);
    final formatter = ref.watch(unitsFormatterProvider);
    final tokens = Theme.of(context).extension<ThemeTokensExtension>()!.tokens;

    return Scaffold(
      appBar: AppBar(title: Text('testers.batteryMonitor'.tr)),
      body: battery.when(
        skipLoadingOnReload: true,
        data: (b) {
          final pct = b.percent.clamp(0, 100);
          return ListView(
            padding: EdgeInsets.all(tokens.space3),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '$pct%',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Spacer(),
                  if (b.charging == true)
                    Chip(
                      avatar: Icon(
                        b.plugged == true
                            ? Icons.power
                            : Icons.battery_charging_full,
                        size: 18,
                        color: tokens.successColor,
                      ),
                      label: Text('battery.charging'.tr),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              SizedBox(height: tokens.space3),
              AppMeter(value: pct / 100),
              SizedBox(height: tokens.space3),
              _VitalsCard(battery: b, prefs: prefs, formatter: formatter),
            ],
          );
        },
        loading: () => const AppLoadingState(),
        error: (error, stack) => AppErrorState(
          title: 'availability.unavailable'.tr,
          message: '$error',
          actionLabel: 'action.retry'.tr,
          onAction: () => ref.invalidate(batteryStreamProvider),
        ),
      ),
    );
  }
}

class _VitalsCard extends StatelessWidget {
  const _VitalsCard({
    required this.battery,
    required this.prefs,
    required this.formatter,
  });

  final BatteryEntity battery;
  final UnitPreferences prefs;
  final UnitsFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<ThemeTokensExtension>()!.tokens;

    String? voltage;
    final v = battery.voltageV;
    if (v != null) voltage = '${v.toStringAsFixed(v.abs() >= 10 ? 1 : 2)} V';

    String? current;
    final ua = battery.currentMicroAmps;
    if (ua != null && !ua.isNaN) {
      current = formatter.formatElectricCurrent(microAmps: ua);
    }

    String? temperature;
    final c = battery.temperatureC;
    if (c != null && c > -40) {
      temperature = formatter.formatTemperature(
        celsius: c,
        unit: prefs.temperature,
      );
    }

    String? capacity;
    final mah = battery.capacityMah;
    if (mah != null) capacity = '${mah.toStringAsFixed(0)} mAh';

    String? power;
    final w = battery.watts;
    if (w != null) power = '${w.toStringAsFixed(w.abs() >= 10 ? 1 : 2)} W';

    final rows = <(String, String)>[
      ('battery.voltage'.tr, voltage ?? '—'),
      ('battery.currentNowUa'.tr, current ?? '—'),
      ('battery.temperature'.tr, temperature ?? '—'),
      ('battery.capacity'.tr, capacity ?? '—'),
      ('battery.chargingPower'.tr, power ?? '—'),
    ];

    return Card(
      child: Padding(
        padding: EdgeInsets.all(tokens.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('battery.vitals'.tr, style: theme.textTheme.titleMedium),
            SizedBox(height: tokens.space1),
            ...rows.map((row) => SpecRow(label: row.$1, value: row.$2)),
          ],
        ),
      ),
    );
  }
}
