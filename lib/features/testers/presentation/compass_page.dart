import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/sensor_derived_providers.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_states.dart';

class CompassPage extends ConsumerWidget {
  const CompassPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heading = ref.watch(headingProvider);
    final theme = Theme.of(context);
    final tokens = theme.extension<ThemeTokensExtension>()!.tokens;

    return Scaffold(
      appBar: AppBar(title: Text('compass.title'.tr)),
      body: SingleChildScrollView(
        child: Center(
          child: heading == null
              ? AppEmptyState(
                  title: 'compass.unavailable'.tr,
                  message: 'compass.unavailableHint'.tr,
                  icon: Icons.explore_off_outlined,
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HeadingDial(heading: heading),
                    SizedBox(height: tokens.space4),
                    Text(
                      '${heading.toStringAsFixed(0)}° · ${_cardinal(heading)}',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  String _cardinal(double deg) {
    const names = [
      'N',
      'NNE',
      'NE',
      'ENE',
      'E',
      'ESE',
      'SE',
      'SSE',
      'S',
      'SSW',
      'SW',
      'WSW',
      'W',
      'WNW',
      'NW',
      'NNW',
    ];
    return names[((deg % 360) / 22.5).round() % 16];
  }
}

/// Rotates along the shortest arc between headings so crossing north does
/// not trigger a full backward spin.
class _HeadingDial extends StatefulWidget {
  const _HeadingDial({required this.heading});

  final double heading;

  @override
  State<_HeadingDial> createState() => _HeadingDialState();
}

class _HeadingDialState extends State<_HeadingDial> {
  double _displayed = 0;

  @override
  void didUpdateWidget(covariant _HeadingDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    var delta = widget.heading - (_displayed % 360);
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    _displayed += delta;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ThemeTokensExtension>()!.tokens;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: -_displayed),
      duration: Duration(milliseconds: tokens.motionFastMs),
      builder: (context, angle, child) {
        return Transform.rotate(angle: angle * math.pi / 180, child: child);
      },
      child: CustomPaint(
        size: const Size.square(280),
        painter: _CompassDial(Theme.of(context)),
      ),
    );
  }
}

class _CompassDial extends CustomPainter {
  _CompassDial(this.theme);

  final ThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final scheme = theme.colorScheme;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = scheme.onSurfaceVariant.withValues(alpha: 0.4),
    );

    void label(String text, double deg, {bool major = false}) {
      final rad = (deg - 90) * math.pi / 180;
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: theme.textTheme.labelLarge?.copyWith(
            color: major
                ? scheme.primary
                : scheme.onSurfaceVariant.withValues(alpha: 0.7),
            fontWeight: major ? FontWeight.bold : FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        center +
            Offset(math.cos(rad), math.sin(rad)) *
                (radius - (major ? 26 : 20)) -
            Offset(tp.width / 2, tp.height / 2),
      );
      tp.dispose();
    }

    for (var i = 0; i < 360; i += 30) {
      label('$i', i.toDouble(), major: i % 90 == 0);
    }
    for (final e in {'N': 0.0, 'E': 90.0, 'S': 180.0, 'W': 270.0}.entries) {
      label(e.key, e.value, major: true);
    }

    final needle = Paint()
      ..color = scheme.error
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, center + Offset(0, -radius + 40), needle);
    canvas.drawCircle(center, 5, Paint()..color = scheme.primary);
  }

  @override
  bool shouldRepaint(_CompassDial oldDelegate) => oldDelegate.theme != theme;
}
