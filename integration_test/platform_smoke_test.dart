import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fidel/platform/android_bridge.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  testWidgets('Android bridge emits battery events', (_) async {
    final first = await AndroidBridge.batteryStream().first;
    expect(first.containsKey('percent'), true);
  }, skip: !isAndroid);
}
