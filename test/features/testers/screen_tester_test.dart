import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:fidel/features/testers/presentation/screen_tester_page.dart';
import 'package:fidel/core/localization/translations.dart';

void main() {
  group('ScreenTesterPage', () {
    testWidgets('renders with initial color', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: GetMaterialApp(
            translations: AppTranslations(),
            locale: const Locale('en', 'US'),
            home: const ScreenTesterPage(),
          ),
        ),
      );

      // Page should render
      expect(find.byType(ScreenTesterPage), findsOneWidget);

      // Should have a ColoredBox with color
      final coloredBox = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(ScreenTesterPage),
          matching: find.byType(ColoredBox),
        ).first,
      );

      expect(coloredBox.color, isNotNull);
    });

    testWidgets('cycles through colors on tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: GetMaterialApp(
            translations: AppTranslations(),
            locale: const Locale('en', 'US'),
            home: const ScreenTesterPage(),
          ),
        ),
      );

      // Get initial color
      ColoredBox coloredBox = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(ScreenTesterPage),
          matching: find.byType(ColoredBox),
        ).first,
      );
      final initialColor = coloredBox.color;

      // Tap to change color
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      // Get new color
      coloredBox = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(ScreenTesterPage),
          matching: find.byType(ColoredBox),
        ).first,
      );
      final newColor = coloredBox.color;

      // Color should have changed
      expect(newColor, isNot(equals(initialColor)));
    });

    testWidgets('has back button in app bar that pops route',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: GetMaterialApp(
            translations: AppTranslations(),
            locale: const Locale('en', 'US'),
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ScreenTesterPage(),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open the screen tester
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Should have app bar
      expect(find.byType(AppBar), findsOneWidget);

      // Tap back button (automatically added by Flutter)
      final backButton = find.byTooltip('Back');
      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Should be back to original page
      expect(find.text('Open'), findsOneWidget);
      expect(find.byType(ScreenTesterPage), findsNothing);
    });
  });
}
