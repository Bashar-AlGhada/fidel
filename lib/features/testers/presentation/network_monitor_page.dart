import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NetworkMonitorPage extends StatelessWidget {
  const NetworkMonitorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('testers.networkMonitor'.tr)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('testers.networkMonitorPlaceholder'.tr),
      ),
    );
  }
}
