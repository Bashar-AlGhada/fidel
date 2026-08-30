import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../application/providers/system_providers.dart';
import '../../../../application/providers/tester_feeds_providers.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_tokens.dart';
import '../../../../core/ui/app_meter.dart';
import '../../../../core/ui/glass_card.dart';
import '../../../../core/ui/severity_chip.dart';
import '../../../../core/ui/spec_row.dart';
import '../../../../domain/entities/testers/network_status_entity.dart';

/// Unwraps a bridge result `{ok, data:{ok, reason}}` into the native
/// payload. Returns `(false, null)` when the method itself failed.
(bool ok, String? reason) unwrapPayload(Map<String, dynamic> result) {
  if (result['ok'] != true) return (false, null);
  final data = result['data'];
  if (data is Map<String, dynamic>) {
    return (data['ok'] == true, data['reason'] as String?);
  }
  if (data is Map) {
    return (data['ok'] == true, data['reason']?.toString());
  }
  return (false, null);
}

Color rssiColor(ThemeTokens tokens, num dbm) {
  if (dbm >= -60) return tokens.successColor;
  if (dbm >= -75) return tokens.warningColor;
  return tokens.dangerColor;
}

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
    final tokens = context.tokens;
    final transportKey = 'network.transport.$transport';

    return GlassCard(
      padding: EdgeInsets.all(tokens.space3),
      child: Row(
        children: [
          Container(
            width: tokens.space4 + 8,
            height: tokens.space4 + 8,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(tokens.radiusMd),
            ),
            child: Icon(
              switch (transport) {
                'wifi' => Icons.wifi,
                'cellular' => Icons.signal_cellular_4_bar,
                'ethernet' => Icons.lan,
                'vpn' => Icons.vpn_lock,
                _ => Icons.portable_wifi_off,
              },
              color: connected ? tokens.successColor : tokens.dangerColor,
            ),
          ),
          SizedBox(width: tokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  connected ? 'network.connected'.tr : 'network.notConnected'.tr,
                  style: theme.textTheme.titleMedium,
                ),
                Text(transportKey.tr, style: AppText.muted(context)),
              ],
            ),
          ),
          SizedBox(width: tokens.space2),
          Wrap(
            spacing: tokens.space1,
            runSpacing: tokens.space1,
            alignment: WrapAlignment.end,
            children: [
              if (nfcPresent == true)
                SeverityChip(
                  level: nfcEnabled == true
                      ? SeverityLevel.success
                      : SeverityLevel.info,
                  label: 'network.nfc'.tr,
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SeverityChip(
                  dot: false,
                  level: metered ? SeverityLevel.warning : SeverityLevel.info,
                  label: metered
                      ? 'network.meteredYes'.tr
                      : 'network.meteredNo'.tr,
                ),
              ),
            ],
          ),
        ],
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
    final tokens = context.tokens;

    String bandLabel() {
      final f = frequencyMhz;
      if (f == null) return '—';
      if (f < 3000) return '2.4 GHz';
      if (f < 6000) return '5 GHz';
      if (f < 10000) return '6 GHz';
      return '${f}MHz';
    }

    return GlassCard(
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
                  style: AppText.numeric(
                    context,
                    color: rssiColor(tokens, rssi!),
                  ),
                ),
            ],
          ),
          SizedBox(height: tokens.space1),
          AppMeter(
            value: rssi == null ? null : _rssiFraction(rssi!),
            gradientFill: rssi != null,
            color: rssi == null ? null : rssiColor(tokens, rssi!),
          ),
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
          ].map((row) => SpecRow(label: row.$1, value: row.$2, numeric: true)),
        ],
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
    final tokens = context.tokens;
    final hasSignal = status.cellDbm != null || status.cellLevel != null;
    final hasType = status.networkType != null;

    if (!hasSignal && !hasType) {
      return const SizedBox.shrink();
    }

    final bars = ((status.cellLevel ?? 0) / 4).clamp(0.0, 1.0);

    return GlassCard(
      padding: EdgeInsets.all(tokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child:
                    Text('network.cellular'.tr, style: theme.textTheme.titleMedium),
              ),
              if (hasType)
                SeverityChip(
                  dot: false,
                  level: SeverityLevel.info,
                  label: status.networkType!,
                ),
            ],
          ),
          SizedBox(height: tokens.space1),
          AppMeter(value: bars, gradientFill: bars > 0),
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
          ].map((row) => SpecRow(label: row.$1, value: row.$2, numeric: true)),
        ],
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
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _scanning) {
      unawaited(_toggle(false));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Stop the hardware scan on leave; ref reads are valid here as long
    // as they happen before super.dispose().
    unawaited(
      ref.read(androidSystemDatasourceProvider).setBleScanningResult(
            enabled: false,
          ),
    );
    super.dispose();
  }

  String _reasonMessage(String? reason) => switch (reason) {
        'adapter_off' => 'network.bleAdapterOff'.tr,
        'permission_denied' => 'network.blePermissionDenied'.tr,
        'scan_failed' => 'network.scanFailed'.tr,
        'unsupported' => 'network.bleUnsupported'.tr,
        _ => 'availability.unavailable'.tr,
      };

  Future<void> _toggle(bool on) async {
    if (_busy || on == _scanning) return;
    _busy = true;

    if (on && defaultTargetPlatform == TargetPlatform.android) {
      // API 31+ gates scanning behind BT runtime permissions; location
      // remains required for scan results visibility pre-S and is
      // harmless to request post-12.
      final statuses = await [
        Permission.locationWhenInUse,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();
      if (!mounted) return;
      final granted = statuses.values.every((s) => s.isGranted || s.isLimited);
      if (!granted) {
        setState(() => _scanning = false);
        _busy = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('network.blePermissionDenied'.tr)),
        );
        return;
      }
    } else if (on) {
      final status = await Permission.locationWhenInUse.request();
      if (!mounted) return;
      if (!status.isGranted && !status.isLimited) {
        _busy = false;
        setState(() => _scanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('network.blePermissionDenied'.tr)),
        );
        return;
      }
    }

    setState(() => _scanning = on);
    final result = await ref
        .read(androidSystemDatasourceProvider)
        .setBleScanningResult(enabled: on);
    _busy = false;
    if (!mounted) return;

    final (ok, reason) = unwrapPayload(result);
    if (!ok) {
      setState(() => _scanning = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_reasonMessage(reason))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return GlassCard(
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
          Text('network.bleHint'.tr, style: AppText.muted(context)),
          SizedBox(height: tokens.space2),
          Consumer(
            builder: (context, ref, _) {
              final status =
                  ref.watch(networkStatusStreamProvider).value;
              final count = _scanning ? status?.bleCount : null;

              if (!_scanning) {
                return Text(
                  'network.bleIdle'.tr,
                  style: AppText.muted(context),
                );
              }

              // Heartbeat frames reset count to 0 while scanning; show a
              // live "listening" pulse instead of stale idle stats.
              if (count != null && count > 0) {
                return Wrap(
                  spacing: tokens.space4,
                  runSpacing: tokens.space2,
                  children: [
                    BleStat(
                      label: 'network.bleDevices'.tr,
                      value: '$count',
                    ),
                    if (status?.bleAvgRssi != null)
                      BleStat(
                        label: 'network.bleAvgRssi'.tr,
                        value:
                            '${status!.bleAvgRssi!.toStringAsFixed(0)} dBm',
                        valueColor: rssiColor(tokens, status.bleAvgRssi!),
                      ),
                    if (status?.bleStrongestRssi != null)
                      BleStat(
                        label: 'network.bleStrongest'.tr,
                        value: '${status!.bleStrongestRssi} dBm',
                        valueColor:
                            rssiColor(tokens, status.bleStrongestRssi!),
                      ),
                  ],
                );
              }

              return Row(
                children: [
                  const _PulsingDot(),
                  SizedBox(width: tokens.space2),
                  Flexible(
                    child: Text(
                      'network.scanningZero'.tr,
                      style: AppText.numeric(
                        context,
                        color: theme.colorScheme.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.25, end: 1.0).animate(_controller),
      child: CircleAvatar(
        radius: 5,
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class BleStat extends StatelessWidget {
  const BleStat({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppText.numeric(context, color: valueColor),
        ),
        Text(label, style: AppText.muted(context)),
      ],
    );
  }
}
