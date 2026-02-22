import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/localization/locale_provider.dart';
import 'core/localization/translations.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_themes.dart';
import 'core/theme/theme_provider.dart';

void main() {
  runApp(const ProviderScope(child: FidelApp()));
}

class FidelApp extends ConsumerWidget {
  const FidelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = buildRouter();
    final locale = ref.watch(localeProvider);
    final mode = ref.watch(themeModeProvider);

    final theme = switch (mode) {
      AppThemeMode.light => buildLightTheme(),
      AppThemeMode.dark => buildDarkTheme(),
      AppThemeMode.amoled => buildAmoledTheme(),
    };

    return GetMaterialApp.router(
      title: 'Fidel',
      translations: AppTranslations(),
      locale: locale,
      fallbackLocale: const Locale('en', 'US'),
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('de', 'DE'),
        Locale('fr', 'FR'),
        Locale('es', 'ES'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: theme,
      routerDelegate: router.routerDelegate,
      routeInformationParser: router.routeInformationParser,
      routeInformationProvider: router.routeInformationProvider,
    );
  }
}
