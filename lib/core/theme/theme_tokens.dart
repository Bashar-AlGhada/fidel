import 'dart:ui';

import 'package:flutter/material.dart';

class ThemeTokens {
  const ThemeTokens({
    required this.grid,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.strokeWidth,
    required this.motionFastMs,
    required this.glassBlurSigma,
    required this.glassTintOpacity,
    required this.glassBorderOpacity,
    required this.successColor,
    required this.warningColor,
    required this.dangerColor,
  });

  final double grid;
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double strokeWidth;
  final int motionFastMs;
  final double glassBlurSigma;
  final double glassTintOpacity;
  final double glassBorderOpacity;
  final Color successColor;
  final Color warningColor;
  final Color dangerColor;

  double get space1 => grid;
  double get space2 => grid * 2;
  double get space3 => grid * 3;
  double get space4 => grid * 4;

  BorderRadius get cardBorderRadius => BorderRadius.circular(radiusLg);

  static const ThemeTokens v2 = ThemeTokens(
    grid: 8,
    radiusSm: 10,
    radiusMd: 14,
    radiusLg: 18,
    strokeWidth: 1.25,
    motionFastMs: 140,
    glassBlurSigma: 14,
    glassTintOpacity: 0.18,
    glassBorderOpacity: 0.28,
    successColor: Color(0xFF2E7D32),
    warningColor: Color(0xFFEF6C00),
    dangerColor: Color(0xFFC62828),
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
        strokeWidth: lerpDouble(
          tokens.strokeWidth,
          other.tokens.strokeWidth,
          t,
        )!,
        motionFastMs:
            (tokens.motionFastMs +
                    ((other.tokens.motionFastMs - tokens.motionFastMs) * t))
                .round(),
        glassBlurSigma: lerpDouble(
          tokens.glassBlurSigma,
          other.tokens.glassBlurSigma,
          t,
        )!,
        glassTintOpacity: lerpDouble(
          tokens.glassTintOpacity,
          other.tokens.glassTintOpacity,
          t,
        )!,
        glassBorderOpacity: lerpDouble(
          tokens.glassBorderOpacity,
          other.tokens.glassBorderOpacity,
          t,
        )!,
        successColor: Color.lerp(
          tokens.successColor,
          other.tokens.successColor,
          t,
        )!,
        warningColor: Color.lerp(
          tokens.warningColor,
          other.tokens.warningColor,
          t,
        )!,
        dangerColor: Color.lerp(
          tokens.dangerColor,
          other.tokens.dangerColor,
          t,
        )!,
      ),
    );
  }
}
