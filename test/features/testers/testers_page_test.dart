import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:fidel/features/testers/presentation/testers_page.dart';
import 'package:fidel/core/theme/app_themes.dart';
import 'package:fidel/core/ui/app_card.dart';
import 'package:fidel/core/localization/translations.dart';

void main() {
  group('TestersPage', () {
    testWidgets('renders testers hub with all tool cards',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: GetMaterialApp(
            translations: AppTranslations(),
            locale: const Locale('en', 'US'),
            theme: buildLightTheme(),
            home: const TestersPage(),
          ),
        ),
      );

      // Wait for async operations to complete
      await tester.pumpAndSettle();

      // Check page title
      expect(find.text('Testers'), findsOneWidget);

      // Check all 5 tester cards are present
      expect(find.text('Screen tester'), findsOneWidget);
      expect(find.text('Noise checker'), findsOneWidget);
      expect(find.text('Battery monitor'), findsOneWidget);
      expect(find.text('Network monitor'), findsOneWidget);
      expect(find.text('CPU monitor'), findsOneWidget);

      // Check icons are present (outlined variants)
      expect(find.byIcon(Icons.smart_display_outlined), findsOneWidget);
      expect(find.byIcon(Icons.graphic_eq_outlined), findsOneWidget);
      expect(find.byIcon(Icons.battery_charging_full_outlined), findsOneWidget);
      expect(find.byIcon(Icons.network_check_outlined), findsOneWidget);
      expect(find.byIcon(Icons.developer_board_outlined), findsOneWidget);
    });

    testWidgets('tester cards are tappable', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: GetMaterialApp(
            translations: AppTranslations(),
            locale: const Locale('en', 'US'),
            theme: buildLightTheme(),
            home: const TestersPage(),
          ),
        ),
      );

      // Wait for async operations to complete
      await tester.pumpAndSettle();

      // Find first card (Screen Tester) - using AppCard instead of Card
      expect(find.byType(AppCard), findsNWidgets(5));
      expect(find.byType(InkWell), findsWidgets);
    });
  });
}
