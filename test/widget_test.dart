// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:fidel/application/providers/system_providers.dart';
import 'package:fidel/main.dart';

void main() {
  testWidgets('App boots smoke test', (tester) async {
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
  });
}
