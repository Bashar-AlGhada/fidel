import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:fidel/application/providers/system_providers.dart';
import 'package:fidel/main.dart';

void main() {
  testWidgets('Shows new bottom navigation destinations', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(420, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Live 1 Hz feeds arm real timeout Timers that would outlive the
          // fake-async zone; navigation smoke tests don't need them.
          batteryStreamProvider.overrideWith((ref) => const Stream.empty()),
          memoryStreamProvider.overrideWith((ref) => const Stream.empty()),
          cpuStreamProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: const FidelApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Summary'), findsWidgets);
    expect(find.text('Info'), findsWidgets);
    expect(find.text('Testers'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });
}
