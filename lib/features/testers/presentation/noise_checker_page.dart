import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../application/providers/tester_feeds_providers.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_meter.dart';
import '../../../core/ui/app_states.dart';
import 'widgets/permission_gate.dart';

class NoiseCheckerPage extends ConsumerStatefulWidget {
  const NoiseCheckerPage({super.key});

  @override
  ConsumerState<NoiseCheckerPage> createState() => _NoiseCheckerPageState();
}

class _NoiseCheckerPageState extends ConsumerState<NoiseCheckerPage>
    with WidgetsBindingObserver {
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
    if (state == AppLifecycleState.paused) {
      ref.invalidate(noiseLevelStreamProvider);
    } else if (state == AppLifecycleState.resumed) {
      setState(() => _statusProbe++);
    }
  }

  Future<void> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    if (!mounted) return;
    setState(() {
      _status = status;
      _statusProbe++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('testers.noiseChecker'.tr)),
      body: Padding(
        padding: EdgeInsets.all(
          Theme.of(context).extension<ThemeTokensExtension>()!.tokens.space3,
        ),
        child: FutureBuilder<PermissionStatus>(
          // The page can be deep-linked with no request ever made; surface
          // the current OS status before asking for anything. Bumping
          // [_statusProbe] re-runs the future after settings changes.
          key: ValueKey(_statusProbe),
          future: _status != null
              ? Future.value(_status)
              : Permission.microphone.status,
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
                onRequest: _requestMicPermission,
                requestLabel: 'testers.requestMicPermission'.tr,
              );
            }
            return const _NoiseMeterView();
          },
        ),
      ),
    );
  }
}

/// Live microphone level readout. SPL is an uncalibrated estimate.
class _NoiseMeterView extends ConsumerWidget {
  const _NoiseMeterView();

  static const double _barFloorDbfs = -60;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levelAsync = ref.watch(noiseLevelStreamProvider);
    final theme = Theme.of(context);

    return levelAsync.when(
      skipLoadingOnReload: true,
      data: (level) {
        final fraction = ((level.dbfs - _barFloorDbfs) / -_barFloorDbfs).clamp(
          0.0,
          1.0,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${'noise.spl'.tr}: ${level.splApprox.toStringAsFixed(1)} dB',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${'noise.levelDb'.tr}: ${level.dbfs.toStringAsFixed(1)} dBFS · '
              '${'noise.peak'.tr}: ${level.peakDbfs.toStringAsFixed(1)} dBFS',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AppMeter(value: fraction, height: 10),
            const SizedBox(height: 12),
            Text(
              'noise.calibrationNote'.tr,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
      loading: () => AppLoadingState(message: 'noise.listening'.tr),
      error: (err, st) => AppErrorState(
        title: 'availability.unavailable'.tr,
        message: '$err',
        actionLabel: 'action.retry'.tr,
        onAction: () => ref.invalidate(noiseLevelStreamProvider),
      ),
    );
  }
}
