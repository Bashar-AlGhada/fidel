import 'package:flutter/material.dart';

/// Tiny inline chart for trends (CPU %, battery drain, noise level).
///
/// Draws a smooth polyline with a soft gradient area fill that fades
/// downward. Auto-scales to the data; degenerate input (empty, single
/// point, flat line) is rendered gracefully as a midline/dot.
class Sparkline extends StatelessWidget {
  const Sparkline({
    required this.data,
    this.color,
    this.strokeWidth = 2,
    this.fill = true,
    super.key,
  });

  /// Sample values in chronological order. May be empty.
  final List<double> data;

  /// Stroke color; defaults to the theme primary.
  final Color? color;

  final double strokeWidth;

  /// Whether to paint the fading area fill under the line.
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? Theme.of(context).colorScheme.primary;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _SparklinePainter(
          data: data,
          color: effectiveColor,
          strokeWidth: strokeWidth,
          fill: fill,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.data,
    required this.color,
    required this.strokeWidth,
    required this.fill,
  });

  final List<double> data;
  final Color color;
  final double strokeWidth;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || size.isEmpty) return;

    var min = data.first;
    var max = data.first;
    for (final v in data) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    // Pad the domain so flat/single-point data sits on a visible midline.
    final span = (max - min).abs();
    final pad = span == 0 ? (min.abs() < 1e-9 ? 1.0 : min.abs() * 0.5) : span * 0.08;
    final lo = min - pad;
    final hi = max + pad;

    final inset = strokeWidth;
    final w = size.width - inset * 2;
    final h = size.height - inset * 2;
    if (w <= 0 || h <= 0) return;

    Offset pointAt(int i) {
      final x = data.length == 1 ? 0.0 : w * i / (data.length - 1);
      final y = h - h * (data[i] - lo) / (hi - lo);
      return Offset(inset + x, inset + y);
    }

    final linePath = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    // Smooth through midpoints with quadratic segments.
    for (var i = 1; i < data.length; i++) {
      final prev = pointAt(i - 1);
      final curr = pointAt(i);
      final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
      linePath.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    linePath.lineTo(pointAt(data.length - 1).dx, pointAt(data.length - 1).dy);

    if (fill && data.length > 1) {
      final fillPath = Path.from(linePath)
        ..lineTo(inset + w, size.height)
        ..lineTo(inset, size.height)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.02)],
          ).createShader(Offset.zero & size),
      );
    }

    canvas.drawPath(
      linePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    // Single point: draw a visible dot so the sparkline isn't blank.
    if (data.length == 1) {
      canvas.drawCircle(pointAt(0), strokeWidth, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.fill != fill;
}
