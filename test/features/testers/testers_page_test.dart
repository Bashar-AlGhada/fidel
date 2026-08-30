import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:fidel/core/localization/translations.dart';
import 'package:fidel/core/theme/app_themes.dart';
import 'package:fidel/core/ui/app_card.dart';
import 'package:fidel/features/testers/presentation/testers_page.dart';

void main() {
  group('TestersPage', () {
    testWidgets('renders testers hub with all tool cards', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          theme: buildLightTheme(),
          home: const TestersPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Page title.
      expect(find.text('Testers'), findsOneWidget);

      // Every tester card is present.
      expect(find.text('Screen tester'), findsOneWidget);
      expect(find.text('Compass'), findsOneWidget);
      expect(find.text('GNSS'), findsOneWidget);
      expect(find.text('Noise checker'), findsOneWidget);
      expect(find.text('Battery monitor'), findsOneWidget);
      expect(find.text('Network monitor'), findsOneWidget);
      expect(find.text('CPU monitor'), findsOneWidget);
      expect(find.text('Vibration test'), findsOneWidget);
      expect(find.text('Flashlight test'), findsOneWidget);
      expect(find.text('Speed test'), findsOneWidget);

      // Outlined icons per card.
      expect(find.byIcon(Icons.smart_display_outlined), findsOneWidget);
      expect(find.byIcon(Icons.explore_outlined), findsOneWidget);
      expect(find.byIcon(Icons.satellite_alt_outlined), findsOneWidget);
      expect(find.byIcon(Icons.graphic_eq_outlined), findsOneWidget);
      expect(find.byIcon(Icons.battery_charging_full_outlined), findsOneWidget);
      expect(find.byIcon(Icons.network_check_outlined), findsOneWidget);
      expect(find.byIcon(Icons.developer_board_outlined), findsOneWidget);
      expect(find.byIcon(Icons.vibration_outlined), findsOneWidget);
      expect(find.byIcon(Icons.flashlight_on_outlined), findsOneWidget);
      expect(find.byIcon(Icons.speed_outlined), findsOneWidget);
    });

    testWidgets('tester cards are tappable', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          theme: buildLightTheme(),
          home: const TestersPage(),
        ),
      );
      await tester.pumpAndSettle();

      // One AppCard per tester tile.
      expect(find.byType(AppCard), findsNWidgets(10));
      expect(find.byType(InkWell), findsWidgets);
    });
  });
}
