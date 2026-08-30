import 'package:flutter/material.dart';

import '../theme/theme_tokens.dart';

/// The app's standard determinate meter: an 8 dp pill with a subtle track.
///
/// Use for live ratios (battery %, signal strength, noise level). For
/// indeterminate loading, use `AppLoadingState` or a bare
/// [LinearProgressIndicator] instead.
class AppMeter extends StatelessWidget {
  const AppMeter({
    required this.value,
    this.height = 8,
    this.rounded = true,
    this.gradientFill = false,
    this.color,
    super.key,
  });

  /// 0..1, or null for indeterminate animation.
  final double? value;
  final double height;

  /// Fully-rounded pill caps. Defaults to true (matches the original look).
  final bool rounded;

  /// Fills the progress with [ThemeTokens.accentGradient] instead of the
  /// flat primary color. Defaults to false (visual parity).
  final bool gradientFill;

  /// Overrides the fill color when [gradientFill] is false.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<ThemeTokensExtension>()!.tokens;
    final radius = BorderRadius.circular(rounded ? 999 : tokens.radiusSm);
    final trackColor = theme.colorScheme.onSurfaceVariant.withValues(
      alpha: 0.15,
    );

    if (value == null) {
      return ClipRRect(
        borderRadius: radius,
        child: LinearProgressIndicator(
          minHeight: height,
          backgroundColor: trackColor,
        ),
      );
    }

    Widget fill() => gradientFill
        ? DecoratedBox(decoration: BoxDecoration(gradient: tokens.accentGradient))
        : ColoredBox(color: color ?? theme.colorScheme.primary);

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value!.clamp(0.0, 1.0)),
          duration: tokens.motionMedium,
          curve: AppMotion.curveStandard,
          builder: (context, animated, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: trackColor),
                FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: animated,
                  child: fill(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
