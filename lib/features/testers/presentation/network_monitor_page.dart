import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/tester_feeds_providers.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_states.dart';
import 'widgets/network_radio_cards.dart';

class NetworkMonitorPage extends ConsumerWidget {
  const NetworkMonitorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(networkStatusStreamProvider);
    final tokens = Theme.of(context).extension<ThemeTokensExtension>()!.tokens;

    return Scaffold(
      appBar: AppBar(title: Text('testers.networkMonitor'.tr)),
      body: statusAsync.when(
        skipLoadingOnReload: true,
        data: (status) => ListView(
          padding: EdgeInsets.all(tokens.space3),
          children: [
            NetworkStatusCard(
              connected: status.connected,
              metered: status.metered,
              transport: status.transport,
              nfcPresent: status.nfcPresent,
              nfcEnabled: status.nfcEnabled,
            ),
            SizedBox(height: tokens.space2),
            if (status.onWifi)
              WifiDetailsCard(
                ssid: status.ssid,
                bssid: status.bssid,
                rssi: status.rssi,
                linkSpeedMbps: status.linkSpeedMbps,
                frequencyMhz: status.frequencyMhz,
                ip: status.ip,
              ),
            if (status.onWifi) SizedBox(height: tokens.space2),
            CellularCard(status: status),
            SizedBox(height: tokens.space2),
            const BluetoothEnvironmentCard(),
          ],
        ),
        loading: () => const AppLoadingState(),
        error: (err, st) => AppErrorState(
          title: 'availability.unavailable'.tr,
          message: '$err',
          actionLabel: 'action.retry'.tr,
          onAction: () => ref.invalidate(networkStatusStreamProvider),
        ),
      ),
    );
  }
}
