import 'package:flutter/material.dart';

import '../theme/theme_tokens.dart';

/// Circular progress gauge with a center slot for a big readout.
///
/// The arc animates smoothly whenever [value] changes (implicit animation);
/// pass the raw target value and let the widget handle the tween.
class RingGauge extends StatelessWidget {
  const RingGauge({
    required this.value,
    this.size = 96,
    this.strokeWidth = 8,
    this.trackColor,
    this.progressColor,
    this.gradientStroke = true,
    this.child,
    super.key,
  });

  /// Progress in 0..1; clamped internally.
  final double value;

  /// Diameter of the gauge.
  final double size;

  /// Arc thickness.
  final double strokeWidth;

  /// Track color; defaults to onSurfaceVariant @ 15% alpha.
  final Color? trackColor;

  /// Solid progress color when [gradientStroke] is false.
  final Color? progressColor;

  /// Stroke the progress arc with [ThemeTokens.accentGradient].
  final bool gradientStroke;

  /// Center slot — typically `AppText.heroNumeric` percentage text.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final track =
        trackColor ??
        theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15);

    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0.0, 1.0)),
      duration: tokens.motionSlow,
      curve: AppMotion.curveEntrance,
      builder: (context, animated, existingChild) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _RingPainter(
                  progress: animated,
                  trackColor: track,
                  progressColor:
                      progressColor ?? theme.colorScheme.primary,
                  gradient: gradientStroke ? tokens.accentGradient : null,
                  strokeWidth: strokeWidth,
                ),
              ),
              if (child != null) Center(child: existingChild ?? child),
            ],
          ),
        );
      },
      // Keep the label subtree identity stable across value changes so
      // count-up text doesn't rebuild its own state.
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.gradient,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;
  final LinearGradient? gradient;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = strokeWidth;
    final rect = Offset.zero & size;
    final arcRect = Rect.fromCircle(
      center: rect.center,
      radius: (size.shortestSide - stroke) / 2,
    );
    const startAngle = -3.141592653589793 / 2; // 12 o'clock
    const fullTurn = 2 * 3.141592653589793;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawCircle(arcRect.center, arcRect.shortestSide / 2, trackPaint);

    if (progress <= 0) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    if (gradient != null) {
      paint.shader = gradient!.createShader(rect);
    } else {
      paint.color = progressColor;
    }
    canvas.drawArc(arcRect, startAngle, fullTurn * progress, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor ||
      oldDelegate.gradient != gradient ||
      oldDelegate.strokeWidth != strokeWidth;
}
