import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/theme_tokens.dart';
import '../../../../core/ui/app_states.dart';
import '../../../../domain/entities/sensors/sensor_reading_entity.dart';

class SensorChart extends StatefulWidget {
  const SensorChart({required this.samples, this.height = 180, this.onRetry, super.key});

  final List<SensorReadingEntity> samples;
  final double height;
  final VoidCallback? onRetry;

  @override
  State<SensorChart> createState() => _SensorChartState();
}

class _SensorChartState extends State<SensorChart> {
  int _sequence = 0;

  @override
  void didUpdateWidget(covariant SensorChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.samples, widget.samples)) {
      _sequence += 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<ThemeTokensExtension>()!.tokens;

    final samples = widget.samples;
    if (samples.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight.isFinite ? math.min(constraints.maxHeight, widget.height) : widget.height;
          return SizedBox(
            height: height,
            child: AppEmptyState(
              title: 'sensor.noData'.tr,
              message: 'sensor.noDataHint'.tr,
              icon: Icons.sensors_off_outlined,
              actionLabel: widget.onRetry == null ? null : 'action.retry'.tr,
              onAction: widget.onRetry,
            ),
          );
        },
      );
    }

    final dims = samples.fold<int>(0, (p, s) => math.max(p, s.values.length));
    var validPoints = 0;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (final s in samples) {
      for (final v in s.values) {
        if (v.isNaN || v.isInfinite) continue;
        validPoints += 1;
        minY = math.min(minY, v);
        maxY = math.max(maxY, v);
      }
    }

    if (dims == 0 || validPoints < 2) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight.isFinite ? math.min(constraints.maxHeight, widget.height) : widget.height;
          return SizedBox(
            height: height,
            child: AppEmptyState(title: 'sensor.notEnoughSamples'.tr, message: 'sensor.notEnoughSamplesHint'.tr, icon: Icons.show_chart),
          );
        },
      );
    }

    if (!minY.isFinite || !maxY.isFinite) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight.isFinite ? math.min(constraints.maxHeight, widget.height) : widget.height;
          return SizedBox(
            height: height,
            child: AppErrorState(
              title: 'sensor.invalidData'.tr,
              message: 'sensor.invalidDataHint'.tr,
              actionLabel: widget.onRetry == null ? null : 'action.retry'.tr,
              onAction: widget.onRetry,
            ),
          );
        },
      );
    }

    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite ? math.min(constraints.maxHeight, widget.height) : widget.height;
        return SizedBox(
          height: height,
          child: RepaintBoundary(
            child: TweenAnimationBuilder<double>(
              key: ValueKey(_sequence),
              duration: Duration(milliseconds: tokens.motionFastMs),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: 0, end: 1),
              builder: (context, t, _) {
                return CustomPaint(
                  painter: _SensorChartPainter(
                    samples: samples,
                    colorScheme: theme.colorScheme,
                    tokens: tokens,
                    dims: dims,
                    minY: minY,
                    maxY: maxY,
                    t: t,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _SensorChartPainter extends CustomPainter {
  _SensorChartPainter({
    required this.samples,
    required this.colorScheme,
    required this.tokens,
    required this.dims,
    required this.minY,
    required this.maxY,
    required this.t,
  });

  final List<SensorReadingEntity> samples;
  final ColorScheme colorScheme;
  final ThemeTokens tokens;
  final int dims;
  final double minY;
  final double maxY;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final r = tokens.radiusSm;
    final bg = Paint()..color = colorScheme.surfaceContainerHighest;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r)), bg);

    final left = tokens.space2;
    final top = tokens.space2;
    final w = size.width - (tokens.space2 * 2);
    final h = size.height - (tokens.space2 * 2);
    if (w <= 0 || h <= 0) return;

    final gridPaint = Paint()
      ..color = colorScheme.onSurfaceVariant.withValues(alpha: 0.18)
      ..strokeWidth = tokens.strokeWidth;
    for (var i = 1; i <= 3; i++) {
      final y = top + (i / 4.0) * h;
      canvas.drawLine(Offset(left, y), Offset(left + w, y), gridPaint);
    }

    final colors = <Color>[colorScheme.primary, colorScheme.tertiary, colorScheme.secondary, colorScheme.error];

    for (var dim = 0; dim < dims; dim++) {
      final linePaint = Paint()
        ..color = colors[dim % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 2.0;

      final path = Path();
      var started = false;

      for (var i = 0; i < samples.length; i++) {
        final s = samples[i];
        if (dim >= s.values.length) continue;
        final v = s.values[dim];
        if (v.isNaN || v.isInfinite) continue;

        final x = left + (i / (samples.length - 1)) * w;
        final norm = (v - minY) / (maxY - minY);
        final yRaw = top + (1.0 - norm) * h;
        final y = (top + h) + (yRaw - (top + h)) * t;

        if (!started) {
          path.moveTo(x, y);
          started = true;
        } else {
          path.lineTo(x, y);
        }
      }

      if (started) {
        canvas.drawPath(path, linePaint);
      }
    }

    final border = Paint()
      ..color = colorScheme.onSurfaceVariant.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = tokens.strokeWidth;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r)), border);
  }

  @override
  bool shouldRepaint(covariant _SensorChartPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.colorScheme != colorScheme ||
        oldDelegate.tokens != tokens ||
        oldDelegate.dims != dims ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        oldDelegate.t != t;
  }
}
