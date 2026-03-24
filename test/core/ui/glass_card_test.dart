import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fidel/core/ui/glass_card.dart';
import 'package:fidel/core/theme/app_themes.dart';

void main() {
  group('GlassCard', () {
    testWidgets('renders child content', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: GlassCard(
              child: Text('Test Content'),
            ),
          ),
        ),
      );

      expect(find.text('Test Content'), findsOneWidget);
    });

    testWidgets('applies custom padding', (WidgetTester tester) async {
      const testPadding = EdgeInsets.all(24.0);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: GlassCard(
              padding: testPadding,
              child: Text('Test'),
            ),
          ),
        ),
      );

      // Find the padding widget directly inside GlassCard
      final glassCard = find.byType(GlassCard);
      expect(glassCard, findsOneWidget);

      // Get the Padding widget containing the test text
      final paddingWithText = find.ancestor(
        of: find.text('Test'),
        matching: find.byType(Padding),
      );

      // Should find at least one padding
      expect(paddingWithText, findsWidgets);

      // Check the padding value on the immediate parent of the text
      final padding = tester.widget<Padding>(paddingWithText.first);
      expect(padding.padding, testPadding);
    });

    testWidgets('responds to tap when onTap provided',
        (WidgetTester tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: GlassCard(
              onTap: () => tapped = true,
              child: const Text('Tap Me'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap Me'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('does not respond to tap when onTap is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: GlassCard(
              child: Text('No Tap'),
            ),
          ),
        ),
      );

      // Should not have InkWell when onTap is null
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('applies semantic label when provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: GlassCard(
              semanticLabel: 'Test Card Label',
              child: Text('Content'),
            ),
          ),
        ),
      );

      final semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byType(GlassCard),
          matching: find.byType(Semantics),
        ),
      );

      expect(semantics.properties.label, 'Test Card Label');
    });

    testWidgets('uses BackdropFilter for glassmorphism effect',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: GlassCard(
              child: Text('Glass'),
            ),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
    });
  });
}
