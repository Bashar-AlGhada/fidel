import 'package:flutter/material.dart';

import 'app_typography.dart';
import 'theme_tokens.dart';

ThemeData buildLightTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0B7285),
    secondary: const Color(0xFFB54708),
    tertiary: const Color(0xFF2F9E44),
  );
  return _buildTheme(colorScheme: colorScheme, isAmoled: false);
}

ThemeData buildDarkTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0B7285),
    secondary: const Color(0xFFFFB86C),
    tertiary: const Color(0xFF74C69D),
    brightness: Brightness.dark,
  );
  return _buildTheme(colorScheme: colorScheme, isAmoled: false);
}

ThemeData buildAmoledTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0B7285),
    secondary: const Color(0xFFFFB86C),
    tertiary: const Color(0xFF74C69D),
    brightness: Brightness.dark,
  );
  final amoled = base.copyWith(
    surface: Colors.black,
    surfaceContainerLow: Colors.black,
    surfaceContainer: const Color(0xFF050505),
    surfaceContainerHigh: const Color(0xFF0C0C0C),
    surfaceContainerHighest: const Color(0xFF121212),
  );
  return _buildTheme(colorScheme: amoled, isAmoled: true);
}

ThemeData _buildTheme({required ColorScheme colorScheme, required bool isAmoled}) {
  final tokens = ThemeTokens.v2;
  final base = colorScheme.brightness == Brightness.dark
      ? ThemeData.dark()
      : ThemeData.light();

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: isAmoled ? Colors.black : colorScheme.surface,
    canvasColor: isAmoled ? Colors.black : colorScheme.surface,
    textTheme: buildAppTextTheme(base.textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: isAmoled ? Colors.black : colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: tokens.cardBorderRadius),
      elevation: 0,
      color: isAmoled ? const Color(0xFF101010) : colorScheme.surfaceContainerHigh,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceContainer,
      selectedColor: colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide.none,
      labelStyle: TextStyle(color: colorScheme.onSurface),
    ),
    dividerTheme: DividerThemeData(
      thickness: tokens.strokeWidth,
      space: tokens.space3,
      color: colorScheme.outlineVariant,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: colorScheme.surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
      ),
    ),
    extensions: [ThemeTokensExtension(tokens)],
  );
}
