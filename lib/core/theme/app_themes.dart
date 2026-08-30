import 'package:flutter/material.dart';

import 'app_typography.dart';
import 'theme_tokens.dart';

ThemeData buildLightTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0B7285),
    secondary: const Color(0xFFB54708),
    tertiary: const Color(0xFF2F9E44),
  );
  // Warmer neutrals for the light mode surface ladder.
  final warm = colorScheme.copyWith(
    surface: const Color(0xFFFAF8F5),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFF5F1EA),
    surfaceContainer: const Color(0xFFEFEBE3),
    surfaceContainerHigh: const Color(0xFFE9E4DB),
    surfaceContainerHighest: const Color(0xFFE2DCD2),
  );
  return _buildTheme(colorScheme: warm, isAmoled: false);
}

ThemeData buildDarkTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0B7285),
    secondary: const Color(0xFFFFB86C),
    tertiary: const Color(0xFF74C69D),
    brightness: Brightness.dark,
  );
  // Deep navy-teal tint ladder instead of pure gray.
  final tinted = colorScheme.copyWith(
    surface: const Color(0xFF0E141A),
    surfaceContainerLowest: const Color(0xFF090F14),
    surfaceContainerLow: const Color(0xFF121A21),
    surfaceContainer: const Color(0xFF16202A),
    surfaceContainerHigh: const Color(0xFF1C2733),
    surfaceContainerHighest: const Color(0xFF26333F),
  );
  return _buildTheme(colorScheme: tinted, isAmoled: false);
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
    surfaceContainerLowest: Colors.black,
    surfaceContainerLow: const Color(0xFF030405),
    surfaceContainer: const Color(0xFF050505),
    surfaceContainerHigh: const Color(0xFF0C0C0C),
    surfaceContainerHighest: const Color(0xFF121212),
  );
  return _buildTheme(colorScheme: amoled, isAmoled: true);
}

ThemeData _buildTheme({
  required ColorScheme colorScheme,
  required bool isAmoled,
}) {
  final isDark = colorScheme.brightness == Brightness.dark;
  final tokens = isDark ? ThemeTokens.v2Dark : ThemeTokens.v2Light;
  final base = isDark ? ThemeData.dark() : ThemeData.light();

  // Slightly translucent card fill so cards sit naturally inside the glass
  // family (backdrop blur reads through without breaking contrast).
  final cardColor = isAmoled
      ? const Color(0xF00C0F12)
      : colorScheme.surfaceContainerHigh.withValues(alpha: isDark ? 0.88 : 0.94);

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
      color: cardColor,
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
