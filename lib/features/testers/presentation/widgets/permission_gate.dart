import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

/// Shared permission gate for tester pages that need a runtime permission
/// before their live feed can start.
///
/// Shows the per-status explanation from the standard
/// `testers.permission*` keys and swaps the action button for an app
/// settings shortcut once the OS has permanently denied the request.
class PermissionGate extends StatelessWidget {
  const PermissionGate({
    required this.status,
    required this.onRequest,
    this.contextMessage,
    required this.requestLabel,
    super.key,
  });

  final PermissionStatus status;
  final Future<void> Function() onRequest;

  /// Optional extra line shown under the status text (e.g. why a feature
  /// needs this permission).
  final String? contextMessage;
  final String requestLabel;

  @override
  Widget build(BuildContext context) {
    final permanentlyDenied = status == PermissionStatus.permanentlyDenied;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_statusText(), textAlign: TextAlign.center),
          if (contextMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              contextMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: permanentlyDenied ? openAppSettings : onRequest,
            child: Text(
              permanentlyDenied ? 'action.openSettings'.tr : requestLabel,
            ),
          ),
        ],
      ),
    );
  }

  String _statusText() {
    return switch (status) {
      PermissionStatus.permanentlyDenied =>
        'testers.permissionPermanentlyDenied'.tr,
      PermissionStatus.denied => 'testers.permissionDenied'.tr,
      PermissionStatus.restricted => 'testers.permissionRestricted'.tr,
      PermissionStatus.limited => 'testers.permissionLimited'.tr,
      PermissionStatus.provisional => 'testers.permissionProvisional'.tr,
      _ => 'testers.permissionUnknown'.tr,
    };
  }
}
