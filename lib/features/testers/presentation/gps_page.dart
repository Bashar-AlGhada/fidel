import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../application/providers/tester_feeds_providers.dart';
import '../../../core/ui/app_states.dart';
import 'widgets/permission_gate.dart';

class GpsPage extends ConsumerStatefulWidget {
  const GpsPage({super.key});

  @override
  ConsumerState<GpsPage> createState() => _GpsPageState();
}

class _GpsPageState extends ConsumerState<GpsPage> with WidgetsBindingObserver {
  PermissionStatus? _status;
  int _statusProbe = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding kills the feed (provider invalidated) and returning
    // re-probes permission so OS changes are picked up without remount.
    if (state == AppLifecycleState.paused) {
      ref.invalidate(gpsFixStreamProvider);
    } else if (state == AppLifecycleState.resumed) {
      setState(() => _statusProbe++);
    }
  }

  Future<void> _requestLocation() async {
    final status = await Permission.locationWhenInUse.request();
    if (!mounted) return;
    setState(() {
      _status = status;
      _statusProbe++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('gnss.title'.tr)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: FutureBuilder<PermissionStatus>(
          // Re-runs after requests/settings changes via [_statusProbe].
          key: ValueKey(_statusProbe),
          future: _status != null
              ? Future.value(_status)
              : Permission.locationWhenInUse.status,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AppErrorState(
                title: 'availability.unavailable'.tr,
                message: '${snapshot.error}',
                actionLabel: 'action.retry'.tr,
                onAction: () => setState(() => _statusProbe++),
              );
            }
            final status = snapshot.data;
            if (status == null) return const AppLoadingState();
            if (status != PermissionStatus.granted) {
              return PermissionGate(
                status: status,
                onRequest: _requestLocation,
                requestLabel: 'action.retry'.tr,
                contextMessage: 'gnss.permissionHint'.tr,
              );
            }
            return const _FixView();
          },
        ),
      ),
    );
  }
}

class _FixView extends ConsumerWidget {
  const _FixView();

  static const double _msToKmh = 3.6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fixAsync = ref.watch(gpsFixStreamProvider);
    final theme = Theme.of(context);

    return fixAsync.when(
      skipLoadingOnReload: true,
      data: (fix) => ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.satellite_alt,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        fix.satellitesUsed == null
                            ? '—'
                            : '${fix.satellitesUsed}/${fix.satellitesTotal ?? '?'}',
                        style: theme.textTheme.titleLarge,
                      ),
                      const Spacer(),
                      if (fix.accuracyM != null)
                        Chip(
                          label: Text(
                            '±${fix.accuracyM!.toStringAsFixed(0)} m',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...[
                    ('gnss.latitude'.tr, fix.latitude.toStringAsFixed(6)),
                    ('gnss.longitude'.tr, fix.longitude.toStringAsFixed(6)),
                    (
                      'gnss.altitude'.tr,
                      fix.altitudeM == null
                          ? 'common.na'.tr
                          : '${fix.altitudeM!.toStringAsFixed(1)} m',
                    ),
                    (
                      'gnss.speed'.tr,
                      fix.speedMps == null
                          ? 'common.na'.tr
                          : '${(fix.speedMps! * _msToKmh).toStringAsFixed(1)} km/h',
                    ),
                    (
                      'gnss.bearing'.tr,
                      fix.bearingDeg == null
                          ? 'common.na'.tr
                          : '${fix.bearingDeg!.toStringAsFixed(0)}°',
                    ),
                  ].map(
                    (row) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(width: 110, child: Text(row.$1)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SelectableText(
                              row.$2,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      loading: () => AppLoadingState(message: 'gnss.waitingFix'.tr),
      error: (err, st) => AppErrorState(
        title: 'availability.unavailable'.tr,
        message: '$err',
        actionLabel: 'action.retry'.tr,
        onAction: () => ref.invalidate(gpsFixStreamProvider),
      ),
    );
  }
}
