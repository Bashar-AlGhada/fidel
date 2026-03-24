import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/theme_tokens.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<ThemeTokensExtension>()!.tokens;
    final colorScheme = theme.colorScheme;
    final radius = BorderRadius.circular(tokens.radiusLg);

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
            border: Border.all(
              color: colorScheme.onSurface.withValues(
                alpha: tokens.glassBorderOpacity,
              ),
            ),
            gradient: LinearGradient(
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
            ),
          ),
          child: Padding(
            padding: padding ?? EdgeInsets.all(tokens.space2),
            child: child,
          ),
        ),
      ),
    );

    if (onTap == null) {
      return Container(margin: margin, child: panel);
    }

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(borderRadius: radius, onTap: onTap, child: panel),
      ),
    );
  }
}
