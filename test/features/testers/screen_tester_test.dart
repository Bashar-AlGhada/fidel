import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:fidel/core/localization/translations.dart';
import 'package:fidel/core/theme/app_themes.dart';
import 'package:fidel/features/testers/presentation/screen_tester_page.dart';

void main() {
  group('ScreenTesterPage', () {
    testWidgets('renders solid mode with an initial color', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          theme: buildLightTheme(),
          home: const ScreenTesterPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ScreenTesterPage), findsOneWidget);

      // Solid mode paints a ColoredBox behind the tap-to-cycle hint.
      final colored = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(ScreenTesterPage),
          matching: find.byType(ColoredBox),
        ).first,
      );
      expect(colored.color, isNotNull);
    });

    testWidgets('cycles through colors on tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          theme: buildLightTheme(),
          home: const ScreenTesterPage(),
        ),
      );
      await tester.pumpAndSettle();

      final initialColor = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(ScreenTesterPage),
          matching: find.byType(ColoredBox),
        ).first,
      ).color;

      // Tap the solid surface (the GestureDetector wrapping the ColoredBox).
      await tester.tap(
        find
            .ancestor(
              of: find.byType(ColoredBox),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      await tester.pumpAndSettle();

      final newColor = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(ScreenTesterPage),
          matching: find.byType(ColoredBox),
        ).first,
      ).color;

      expect(newColor, isNot(equals(initialColor)));
    });

    testWidgets('has a back button that pops the route', (
      WidgetTester tester,
    ) async {
      // The page's back button relies on GoRouter (context.pop), so it must
      // be reached through a GoRouter just like in the real app.
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: ElevatedButton(
                onPressed: () => context.push('/screen'),
                child: const Text('Open'),
              ),
            ),
          ),
          GoRoute(
            path: '/screen',
            builder: (context, state) => const ScreenTesterPage(),
          ),
        ],
      );

      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          theme: buildLightTheme(),
          home: MaterialApp.router(
            routerConfig: router,
            theme: buildLightTheme(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // The page uses an immersive chrome with a back IconButton whose
      // tooltip is the Material default (en_US -> "Back").
      final backButton = find.byTooltip('Back');
      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Popping returns to the previous route: the tester page is gone.
      expect(find.byType(ScreenTesterPage), findsNothing);
      expect(find.text('Open'), findsWidgets);
    });
  });
}
