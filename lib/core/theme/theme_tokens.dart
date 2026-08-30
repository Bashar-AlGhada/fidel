import 'dart:ui';

import 'package:flutter/material.dart';

/// Motion curves cannot be lerped inside [ThemeExtension], so they live as
/// static constants here and pair with the Duration tokens on [ThemeTokens].
abstract final class AppMotion {
  /// Entrances: fade/slide-in of cards, tiles and list items.
  static const Curve curveEntrance = Curves.easeOutCubic;

  /// Exits and dismissals.
  static const Curve curveExit = Curves.easeInCubic;

  /// Standard interactive transitions (color, position, size).
  static const Curve curveStandard = Curves.easeInOutCubicEmphasized;

  /// Playful overshoot for gauges/count-ups.
  static const Curve curveSpring = Curves.easeOutBack;

  static Duration durationMs(int ms) => Duration(milliseconds: ms);
}

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
    this.accentGradient = _defaultAccentGradient,
    this.motionMediumMs = 240,
    this.motionSlowMs = 400,
  });

  static const LinearGradient _defaultAccentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0E7490), Color(0xFF74C69D)],
  );

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

  /// Subtle primary→tertiary sweep for hero surfaces, meter fills and
  /// highlighted borders.
  final LinearGradient accentGradient;

  /// Medium transitions: card entrance stagger, gauge sweeps.
  final int motionMediumMs;

  /// Slow transitions: count-up feel, large surface morphs.
  final int motionSlowMs;

  double get space1 => grid;
  double get space2 => grid * 2;
  double get space3 => grid * 3;
  double get space4 => grid * 4;

  Duration get motionFast => AppMotion.durationMs(motionFastMs);
  Duration get motionMedium => AppMotion.durationMs(motionMediumMs);
  Duration get motionSlow => AppMotion.durationMs(motionSlowMs);

  BorderRadius get cardBorderRadius => BorderRadius.circular(radiusLg);

  /// Dark preset — brighter semantic hues tuned against dark surfaces.
  static const ThemeTokens v2Dark = ThemeTokens(
    grid: 8,
    radiusSm: 10,
    radiusMd: 14,
    radiusLg: 18,
    strokeWidth: 1.25,
    motionFastMs: 140,
    glassBlurSigma: 14,
    glassTintOpacity: 0.18,
    glassBorderOpacity: 0.28,
    successColor: Color(0xFF5BD08C),
    warningColor: Color(0xFFFFB86C),
    dangerColor: Color(0xFFFF7B72),
    accentGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0E7490), Color(0xFF74C69D)],
    ),
    motionMediumMs: 240,
    motionSlowMs: 400,
  );

  /// Light preset — deeper semantic hues with sufficient contrast on warm
  /// light surfaces.
  static const ThemeTokens v2Light = ThemeTokens(
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
    warningColor: Color(0xFFB45309),
    dangerColor: Color(0xFFC62828),
    accentGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0B7285), Color(0xFF2F9E44)],
    ),
    motionMediumMs: 240,
    motionSlowMs: 400,
  );

  /// Legacy alias kept for backward compatibility (dark is the default mode).
  static const ThemeTokens v2 = v2Dark;
}

/// Convenience accessor replacing
/// `Theme.of(context).extension<ThemeTokensExtension>()!.tokens`.
extension ThemeTokensContext on BuildContext {
  ThemeTokens get tokens =>
      Theme.of(this).extension<ThemeTokensExtension>()!.tokens;
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
        accentGradient: LinearGradient.lerp(
          tokens.accentGradient,
          other.tokens.accentGradient,
          t,
        )!,
        motionMediumMs:
            (tokens.motionMediumMs +
                    ((other.tokens.motionMediumMs - tokens.motionMediumMs) * t))
                .round(),
        motionSlowMs:
            (tokens.motionSlowMs +
                    ((other.tokens.motionSlowMs - tokens.motionSlowMs) * t))
                .round(),
      ),
    );
  }
}
