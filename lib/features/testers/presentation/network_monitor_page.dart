import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/tester_feeds_providers.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_page_scaffold.dart';
import '../../../core/ui/async_value_view.dart';
import '../../../domain/entities/testers/network_status_entity.dart';
import 'widgets/network_radio_cards.dart';

class NetworkMonitorPage extends ConsumerWidget {
  const NetworkMonitorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;

    return AppPageScaffold(
      title: 'testers.networkMonitor'.tr,
      children: [
        AsyncValueView<NetworkStatusEntity>(
          value: ref.watch(networkStatusStreamProvider),
          errorTitle: 'availability.unavailable'.tr,
          retryLabel: 'action.retry'.tr,
          onRetry: () => ref.invalidate(networkStatusStreamProvider),
          data: (status) => Column(
            children: [
              NetworkStatusCard(
                connected: status.connected,
                metered: status.metered,
                transport: status.transport,
                nfcPresent: status.nfcPresent,
                nfcEnabled: status.nfcEnabled,
              ),
              if (status.onWifi) ...[
                SizedBox(height: tokens.space2),
                WifiDetailsCard(
                  ssid: status.ssid,
                  bssid: status.bssid,
                  rssi: status.rssi,
                  linkSpeedMbps: status.linkSpeedMbps,
                  frequencyMhz: status.frequencyMhz,
                  ip: status.ip,
                ),
              ],
              SizedBox(height: tokens.space2),
              CellularCard(status: status),
              SizedBox(height: tokens.space2),
              const BluetoothEnvironmentCard(),
            ],
          ),
        ),
      ],
    );
  }
}
