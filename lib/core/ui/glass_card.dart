import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/theme_tokens.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.semanticLabel,
    this.gradientTint = false,
    this.highlightBorder = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final String? semanticLabel;

  /// Overlays a low-alpha [ThemeTokens.accentGradient] sweep on the glass
  /// for hero/expressive surfaces. Defaults to false (visual parity).
  final bool gradientTint;

  /// Draws an accent-gradient border instead of the neutral hairline.
  /// Defaults to false (visual parity).
  final bool highlightBorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<ThemeTokensExtension>()!.tokens;
    final colorScheme = theme.colorScheme;
    final radius = BorderRadius.circular(tokens.radiusLg);

    final baseGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        colorScheme.surfaceContainerHighest.withValues(
          alpha: tokens.glassTintOpacity + 0.08,
        ),
        colorScheme.surfaceContainerHigh.withValues(
          alpha: tokens.glassTintOpacity,
        ),
      ],
    );

    final gradient = gradientTint
        ? LinearGradient(
            begin: baseGradient.begin,
            end: baseGradient.end,
            colors: [
              ...baseGradient.colors,
              ...tokens.accentGradient.colors.map(
                (c) => c.withValues(alpha: tokens.glassTintOpacity * 0.55),
              ),
            ],
          )
        : baseGradient;

    final panel = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: tokens.glassBlurSigma,
          sigmaY: tokens.glassBlurSigma,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: highlightBorder
                ? Border.all(color: Colors.transparent)
                : Border.all(
                    color: colorScheme.onSurface.withValues(
                      alpha: tokens.glassBorderOpacity,
                    ),
                  ),
            gradient: gradient,
          ),
          child: Padding(
            padding: padding ?? EdgeInsets.all(tokens.space2),
            child: child,
          ),
        ),
      ),
    );

    final borderedPanel = highlightBorder
        ? CustomPaint(
            foregroundPainter: _GradientBorderPainter(
              radius: radius,
              gradient: tokens.accentGradient,
              strokeWidth: tokens.strokeWidth,
            ),
            child: panel,
          )
        : panel;

    final wrappedPanel = semanticLabel != null
        ? Semantics(label: semanticLabel, child: borderedPanel)
        : borderedPanel;

    if (onTap == null) {
      return Container(margin: margin, child: wrappedPanel);
    }

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(borderRadius: radius, onTap: onTap, child: wrappedPanel),
      ),
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  const _GradientBorderPainter({
    required this.radius,
    required this.gradient,
    required this.strokeWidth,
  });

  final BorderRadius radius;
  final LinearGradient gradient;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = radius.toRRect(Offset.zero & size).deflate(strokeWidth / 2);
    final rect = Offset.zero & size;
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..shader = gradient.createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_GradientBorderPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.gradient != gradient ||
      oldDelegate.strokeWidth != strokeWidth;
}
