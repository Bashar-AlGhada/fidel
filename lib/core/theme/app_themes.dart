import 'package:flutter/material.dart';

import 'app_typography.dart';
import 'theme_tokens.dart';

ThemeData buildLightTheme() {
  final tokens = ThemeTokens.v2;
  final colorScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB));
  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    textTheme: buildAppTextTheme(ThemeData.light().textTheme),
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: tokens.cardBorderRadius),
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
    ),
    dividerTheme: DividerThemeData(thickness: tokens.strokeWidth, space: tokens.space4),
    inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(tokens.radiusMd))),
    extensions: [ThemeTokensExtension(tokens)],
  );
}

ThemeData buildDarkTheme() {
  final tokens = ThemeTokens.v2;
  final colorScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB), brightness: Brightness.dark);
  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    textTheme: buildAppTextTheme(ThemeData.dark().textTheme),
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: tokens.cardBorderRadius),
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
    ),
    dividerTheme: DividerThemeData(thickness: tokens.strokeWidth, space: tokens.space4),
    inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(tokens.radiusMd))),
    extensions: [ThemeTokensExtension(tokens)],
  );
}

ThemeData buildAmoledTheme() {
  final tokens = ThemeTokens.v2;
  final colorScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB), brightness: Brightness.dark);
  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: Colors.black,
    useMaterial3: true,
    textTheme: buildAppTextTheme(ThemeData.dark().textTheme),
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: tokens.cardBorderRadius),
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
    ),
    dividerTheme: DividerThemeData(thickness: tokens.strokeWidth, space: tokens.space4),
    inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(tokens.radiusMd))),
    extensions: [ThemeTokensExtension(tokens)],
  );
}
