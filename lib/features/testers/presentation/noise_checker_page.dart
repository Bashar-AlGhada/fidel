import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class NoiseCheckerPage extends StatefulWidget {
  const NoiseCheckerPage({super.key});

  @override
  State<NoiseCheckerPage> createState() => _NoiseCheckerPageState();
}

class _NoiseCheckerPageState extends State<NoiseCheckerPage> {
  PermissionStatus? _status;

  Future<void> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    if (!mounted) return;
    setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final statusText = switch (status) {
      PermissionStatus.granted => 'testers.permissionGranted'.tr,
      PermissionStatus.denied => 'testers.permissionDenied'.tr,
      PermissionStatus.permanentlyDenied =>
        'testers.permissionPermanentlyDenied'.tr,
      PermissionStatus.restricted => 'testers.permissionRestricted'.tr,
      PermissionStatus.limited => 'testers.permissionLimited'.tr,
      PermissionStatus.provisional => 'testers.permissionProvisional'.tr,
      null => 'testers.permissionUnknown'.tr,
    };

    return Scaffold(
      appBar: AppBar(title: Text('testers.noiseChecker'.tr)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'testers.noiseCheckerPlaceholder'.tr,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Text(statusText),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _requestMicPermission,
              child: Text('testers.requestMicPermission'.tr),
            ),
          ],
        ),
      ),
    );
  }
}
