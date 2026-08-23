import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../application/providers/tester_feeds_providers.dart';
import '../../../../core/theme/theme_tokens.dart';
import '../../../../core/ui/app_meter.dart';
import '../../../../domain/entities/testers/network_status_entity.dart';
import '../../../sections/presentation/widgets/section_cards.dart';

class NetworkStatusCard extends StatelessWidget {
  const NetworkStatusCard({
    super.key,
    required this.connected,
    required this.metered,
    required this.transport,
    this.nfcPresent,
    this.nfcEnabled,
  });

  final bool connected;
  final bool metered;
  final String transport;
  final bool? nfcPresent;
  final bool? nfcEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<ThemeTokensExtension>()!.tokens;
    final transportKey = 'network.transport.$transport';

    return Card(
      child: ListTile(
        leading: Icon(switch (transport) {
          'wifi' => Icons.wifi,
          'cellular' => Icons.signal_cellular_4_bar,
          'ethernet' => Icons.lan,
          'vpn' => Icons.vpn_lock,
          _ => Icons.portable_wifi_off,
        }, color: connected ? tokens.successColor : tokens.dangerColor),
        title: Text(
          connected ? 'network.connected'.tr : 'network.notConnected'.tr,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(transportKey.tr),
        trailing: Wrap(
          spacing: tokens.space1,
          runSpacing: tokens.space1,
          alignment: WrapAlignment.end,
          children: [
            if (nfcPresent == true)
              Chip(
                avatar: Icon(
                  Icons.nfc,
                  size: 16,
                  color: nfcEnabled == true
                      ? tokens.successColor
                      : theme.colorScheme.onSurfaceVariant,
                ),
                label: Text('network.nfc'.tr),
                visualDensity: VisualDensity.compact,
              ),
            Chip(
              label: Text(
                metered ? 'network.meteredYes'.tr : 'network.meteredNo'.tr,
                style: theme.textTheme.labelSmall,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class WifiDetailsCard extends StatelessWidget {
  const WifiDetailsCard({
    super.key,
    required this.ssid,
    required this.bssid,
    required this.rssi,
    required this.linkSpeedMbps,
    required this.frequencyMhz,
    required this.ip,
  });

  final String? ssid;
  final String? bssid;
  final int? rssi;
  final int? linkSpeedMbps;
  final int? frequencyMhz;
  final String? ip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<ThemeTokensExtension>()!.tokens;

    String bandLabel() {
      final f = frequencyMhz;
      if (f == null) return '—';
      if (f < 3000) return '2.4 GHz';
      if (f < 6000) return '5 GHz';
      if (f < 10000) return '6 GHz';
      return '${f}MHz';
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(tokens.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('network.wifi'.tr, style: theme.textTheme.titleMedium),
                const Spacer(),
                if (rssi != null)
                  Text(
                    '$rssi dBm',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: tokens.successColor,
                    ),
                  ),
              ],
            ),
            SizedBox(height: tokens.space1),
            AppMeter(value: rssi == null ? null : _rssiFraction(rssi!)),
            SizedBox(height: tokens.space2),
            ...[
              ('network.ssid'.tr, ssid ?? 'common.na'.tr),
              ('network.bssid'.tr, bssid ?? 'common.na'.tr),
              (
                'network.linkSpeed'.tr,
                linkSpeedMbps == null ? '—' : '$linkSpeedMbps Mbps',
              ),
              ('network.band'.tr, bandLabel()),
              ('network.ip'.tr, ip ?? 'common.na'.tr),
            ].map((row) => SpecRow(label: row.$1, value: row.$2)),
          ],
        ),
      ),
    );
  }

  /// Maps typical Wi-Fi RSSI (-100..-30 dBm) onto a signal bar.
  double _rssiFraction(int rssi) => ((rssi + 100) / 70).clamp(0.0, 1.0);
}

class CellularCard extends StatelessWidget {
  const CellularCard({super.key, required this.status});

  final NetworkStatusEntity status;

  String? get _levelLabel {
    final level = status.cellLevel;
    if (level == null) return null;
    return 'network.cellLevel.$level'.tr;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<ThemeTokensExtension>()!.tokens;
    final hasSignal = status.cellDbm != null || status.cellLevel != null;
    final hasType = status.networkType != null;

    if (!hasSignal && !hasType) {
      return const SizedBox.shrink();
    }

    final bars = ((status.cellLevel ?? 0) / 4).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(tokens.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('network.cellular'.tr, style: theme.textTheme.titleMedium),
                const Spacer(),
                if (hasType)
                  Chip(
                    label: Text(status.networkType!),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            SizedBox(height: tokens.space1),
            AppMeter(value: bars),
            SizedBox(height: tokens.space2),
            ...[
              (
                'network.rssi'.tr,
                hasSignal ? '${status.cellDbm ?? '?'} dBm' : 'common.na'.tr,
              ),
              ('network.signalQuality'.tr, _levelLabel ?? 'common.na'.tr),
              (
                'network.data'.tr,
                (status.dataConnected ?? false)
                    ? 'network.dataOn'.tr
                    : 'network.dataOff'.tr,
              ),
              (
                'network.roaming'.tr,
                (status.roaming ?? false) ? 'common.yes'.tr : 'common.no'.tr,
              ),
            ].map((row) => SpecRow(label: row.$1, value: row.$2)),
          ],
        ),
      ),
    );
  }
}

class BluetoothEnvironmentCard extends ConsumerStatefulWidget {
  const BluetoothEnvironmentCard({super.key});

  @override
  ConsumerState<BluetoothEnvironmentCard> createState() =>
      _BluetoothEnvironmentCardState();
}

class _BluetoothEnvironmentCardState
    extends ConsumerState<BluetoothEnvironmentCard>
    with WidgetsBindingObserver {
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _scanning) {
      _toggle(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Stop the hardware scan on leave; ref reads are valid here as long
    // as they happen before super.dispose().
    ref.read(setBleScanningProvider)(false);
    super.dispose();
  }

  Future<void> _toggle(bool on) async {
    if (on) {
      // API 31+ gates scanning behind runtime permissions; without them
      // the native side silently no-ops.
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();
      if (!mounted) return;
      final granted = statuses.values.every((s) => s.isGranted || s.isLimited);
      if (!granted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('network.blePermission'.tr)));
        return;
      }
    }
    setState(() => _scanning = on);
    final accepted = await ref.read(setBleScanningProvider)(on);
    if (!accepted && mounted) {
      setState(() => _scanning = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('availability.unavailable'.tr)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<ThemeTokensExtension>()!.tokens;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(tokens.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'network.bleEnv'.tr,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Switch(value: _scanning, onChanged: (v) => _toggle(v)),
              ],
            ),
            Text(
              'network.bleHint'.tr,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: tokens.space2),
            Consumer(
              builder: (context, ref, _) {
                final status = ref
                    .watch(networkStatusStreamProvider)
                    .asData
                    ?.value;
                final count = _scanning ? status?.bleCount : null;
                if (!_scanning || count == null) {
                  return Text(
                    'network.bleIdle'.tr,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                }
                return Row(
                  children: [
                    BleStat(label: 'network.bleDevices'.tr, value: '$count'),
                    SizedBox(width: tokens.space3),
                    BleStat(
                      label: 'network.bleAvgRssi'.tr,
                      value:
                          '${status?.bleAvgRssi?.toStringAsFixed(0) ?? '?'} dBm',
                    ),
                    SizedBox(width: tokens.space3),
                    BleStat(
                      label: 'network.bleStrongest'.tr,
                      value: '${status?.bleStrongestRssi ?? '?'} dBm',
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class BleStat extends StatelessWidget {
  const BleStat({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: theme.textTheme.titleLarge),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
