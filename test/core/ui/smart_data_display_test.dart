import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fidel/core/ui/smart_data_display.dart';
import 'package:fidel/core/theme/app_themes.dart';

void main() {
  group('SmartDataDisplay', () {
    testWidgets('renders simple string value', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: SmartDataDisplay(data: 'Simple string'),
          ),
        ),
      );

      expect(find.text('Simple string'), findsOneWidget);
    });

    testWidgets('renders null as N/A', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: SmartDataDisplay(data: null),
          ),
        ),
      );

      expect(find.text('N/A'), findsOneWidget);
    });

    testWidgets('renders number value', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: SmartDataDisplay(data: 42),
          ),
        ),
      );

      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('renders boolean value', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: SmartDataDisplay(data: true),
          ),
        ),
      );

      expect(find.text('true'), findsOneWidget);
    });

    testWidgets('renders Map with keys and values',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: SmartDataDisplay(
              data: {'key1': 'value1', 'key2': 42},
            ),
          ),
        ),
      );

      // Keys are shown without colons
      expect(find.text('key1'), findsOneWidget);
      expect(find.text('value1'), findsOneWidget);
      expect(find.text('key2'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('renders empty Map as Empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: SmartDataDisplay(data: {}),
          ),
        ),
      );

      expect(find.text('Empty'), findsOneWidget);
    });

    testWidgets('renders List items with bullets',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: SmartDataDisplay(
              data: ['item1', 'item2', 'item3'],
            ),
          ),
        ),
      );

      // List items are prefixed with bullets
      expect(find.text('• item1'), findsOneWidget);
      expect(find.text('• item2'), findsOneWidget);
      expect(find.text('• item3'), findsOneWidget);
    });

    testWidgets('renders empty List as Empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: SmartDataDisplay(data: []),
          ),
        ),
      );

      expect(find.text('Empty'), findsOneWidget);
    });

    testWidgets('handles nested Map structure', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: SmartDataDisplay(
              data: {
                'outer': {'inner': 'value'},
              },
            ),
          ),
        ),
      );

      expect(find.text('outer'), findsOneWidget);
      expect(find.text('inner'), findsOneWidget);
      expect(find.text('value'), findsOneWidget);
    });

    testWidgets('handles nested List in Map', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: SmartDataDisplay(
              data: {
                'items': ['a', 'b', 'c'],
              },
            ),
          ),
        ),
      );

      expect(find.text('items'), findsOneWidget);
      expect(find.text('• a'), findsOneWidget);
      expect(find.text('• b'), findsOneWidget);
      expect(find.text('• c'), findsOneWidget);
    });
  });
}
