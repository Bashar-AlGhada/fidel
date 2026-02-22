import 'package:flutter/material.dart';

class ThemeTokens {
  const ThemeTokens({required this.cardRadius, required this.grid});

  final double cardRadius;
  final double grid;

  static const ThemeTokens v1 = ThemeTokens(cardRadius: 24, grid: 8);
}

class ThemeTokensExtension extends ThemeExtension<ThemeTokensExtension> {
  const ThemeTokensExtension(this.tokens);

  final ThemeTokens tokens;

  @override
  ThemeTokensExtension copyWith({ThemeTokens? tokens}) {
    return ThemeTokensExtension(tokens ?? this.tokens);
  }

  @override
  ThemeTokensExtension lerp(
    ThemeExtension<ThemeTokensExtension>? other,
    double t,
  ) {
    if (other is! ThemeTokensExtension) return this;
    return t < 0.5 ? this : other;
  }
}
