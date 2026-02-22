import 'dart:ui';

import 'package:flutter/material.dart';

class ThemeTokens {
  const ThemeTokens({
    required this.grid,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusXl,
    required this.strokeWidth,
    required this.motionFastMs,
    required this.motionNormalMs,
  });

  final double grid;
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusXl;
  final double strokeWidth;
  final int motionFastMs;
  final int motionNormalMs;

  double get space1 => grid;
  double get space2 => grid * 2;
  double get space3 => grid * 3;
  double get space4 => grid * 4;
  double get space5 => grid * 5;
  double get space6 => grid * 6;

  BorderRadius get cardBorderRadius => BorderRadius.circular(radiusLg);

  static const ThemeTokens v2 = ThemeTokens(
    grid: 8,
    radiusSm: 10,
    radiusMd: 14,
    radiusLg: 18,
    radiusXl: 24,
    strokeWidth: 1.25,
    motionFastMs: 140,
    motionNormalMs: 220,
  );
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
    return ThemeTokensExtension(
      ThemeTokens(
        grid: lerpDouble(tokens.grid, other.tokens.grid, t)!,
        radiusSm: lerpDouble(tokens.radiusSm, other.tokens.radiusSm, t)!,
        radiusMd: lerpDouble(tokens.radiusMd, other.tokens.radiusMd, t)!,
        radiusLg: lerpDouble(tokens.radiusLg, other.tokens.radiusLg, t)!,
        radiusXl: lerpDouble(tokens.radiusXl, other.tokens.radiusXl, t)!,
        strokeWidth: lerpDouble(tokens.strokeWidth, other.tokens.strokeWidth, t)!,
        motionFastMs: (tokens.motionFastMs +
                ((other.tokens.motionFastMs - tokens.motionFastMs) * t))
            .round(),
        motionNormalMs: (tokens.motionNormalMs +
                ((other.tokens.motionNormalMs - tokens.motionNormalMs) * t))
            .round(),
      ),
    );
  }
}
