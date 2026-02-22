import 'package:flutter/material.dart';

import 'theme_tokens.dart';

ThemeData buildLightTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    useMaterial3: true,
    extensions: const [ThemeTokensExtension(ThemeTokens.v1)],
  );
}

ThemeData buildDarkTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
    extensions: const [ThemeTokensExtension(ThemeTokens.v1)],
  );
}

ThemeData buildAmoledTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: Colors.black,
    useMaterial3: true,
    extensions: const [ThemeTokensExtension(ThemeTokens.v1)],
  );
}
