import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/glass_card.dart';

enum _ScreenMode { solid, touch, deadPixel, gradient }

class ScreenTesterPage extends StatefulWidget {
  const ScreenTesterPage({super.key});

  @override
  State<ScreenTesterPage> createState() => _ScreenTesterPageState();
}

class _ScreenTesterPageState extends State<ScreenTesterPage> {
  static const List<Color> _solidColors = [
    Colors.black,
    Colors.white,
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.yellow,
    Colors.cyan,
    Color(0xFFFF00FF),
  ];
  static const List<Color> _deadPixelColors = [
    Color(0xFFFF0000),
    Color(0xFF00FF00),
    Color(0xFF0000FF),
    Color(0xFFFFFFFF),
    Color(0xFF000000),
  ];

  static const _chromeHideDelay = Duration(seconds: 3);
  static const _trailFadeDuration = Duration(milliseconds: 350);

  _ScreenMode _mode = _ScreenMode.solid;
  bool _chromeVisible = true;
  Timer? _chromeTimer;

  // Solid mode.
  int _colorIndex = 0;
  bool _autoCycle = false;
  Timer? _autoTimer;

  // Touch canvas mode.
  final Map<int, List<Offset>> _trails = {};
  final Map<int, DateTime> _fadeDeadlines = {};
  final ValueNotifier<int> _canvasTick = ValueNotifier(0);
  Timer? _pruneTimer;
  int _activePointers = 0;
  int _maxActivePointers = 0;

  // Dead pixel mode.
  bool _deadPixelIntro = true;
  int _deadPixelIndex = 0;

  // Gradient mode.
  bool _grayRamp = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _scheduleChromeHide();
  }

  @override
  void dispose() {
    _chromeTimer?.cancel();
    _autoTimer?.cancel();
    _pruneTimer?.cancel();
    _canvasTick.dispose();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  void _bumpCanvas() => _canvasTick.value++;

  void _restoreUiOnPop(bool didPop, Object? result) {
    if (didPop) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
  }

  void _scheduleChromeHide() {
    _chromeTimer?.cancel();
    if (!_chromeVisible) return;
    _chromeTimer = Timer(_chromeHideDelay, () {
      if (mounted) setState(() => _chromeVisible = false);
    });
  }

  void _revealChrome() {
    if (!_chromeVisible) setState(() => _chromeVisible = true);
    _scheduleChromeHide();
  }

  void _setMode(_ScreenMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _autoTimer?.cancel();
      _autoCycle = false;
      _trails.clear();
      _fadeDeadlines.clear();
      _activePointers = 0;
      _maxActivePointers = 0;
      _deadPixelIntro = true;
      _deadPixelIndex = 0;
    });
    _revealChrome();
  }

  // --- Solid mode ---------------------------------------------------------

  void _cycleColor() {
    setState(() => _colorIndex = (_colorIndex + 1) % _solidColors.length);
  }

  void _toggleAutoCycle(bool on) {
    _autoTimer?.cancel();
    setState(() => _autoCycle = on);
    if (on) {
      _autoTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (mounted) _cycleColor();
      });
    }
    _revealChrome();
  }

  // --- Touch canvas mode --------------------------------------------------

  void _onPointerDown(PointerDownEvent event) {
    setState(() {
      _trails[event.pointer] = [event.position];
      _activePointers++;
      _maxActivePointers = math.max(_maxActivePointers, _activePointers);
    });
    _bumpCanvas();
    _ensurePruneTimer();
  }

  void _onPointerMove(PointerMoveEvent event) {
    _trails[event.pointer]?.add(event.position);
    _bumpCanvas();
  }

  void _onPointerUp(PointerEvent event) {
    if (!_trails.containsKey(event.pointer)) return;
    _fadeDeadlines[event.pointer] = DateTime.now().add(_trailFadeDuration);
    setState(() => _activePointers = math.max(0, _activePointers - 1));
    _bumpCanvas();
  }

  void _clearTrails() {
    setState(() {
      _trails.clear();
      _fadeDeadlines.clear();
      _activePointers = 0;
      _maxActivePointers = 0;
    });
    _bumpCanvas();
  }

  void _ensurePruneTimer() {
    _pruneTimer ??= Timer.periodic(const Duration(milliseconds: 40), (_) {
      final now = DateTime.now();
      final expired = _fadeDeadlines.entries
          .where((e) => now.isAfter(e.value))
          .map((e) => e.key)
          .toList();
      if (expired.isEmpty) return;
      setState(() {
        for (final id in expired) {
          _trails.remove(id);
          _fadeDeadlines.remove(id);
        }
      });
      _bumpCanvas();
      if (_trails.isEmpty && mounted && _pruneTimer != null) {
        _pruneTimer!.cancel();
        _pruneTimer = null;
      }
    });
  }

  // --- Dead pixel mode ----------------------------------------------------

  void _advanceDeadPixel() {
    if (_deadPixelIntro) {
      setState(() {
        _deadPixelIntro = false;
        _deadPixelIndex = 0;
      });
    } else if (_deadPixelIndex + 1 >= _deadPixelColors.length) {
      setState(() {
        _deadPixelIntro = true;
        _deadPixelIndex = 0;
      });
    } else {
      setState(() => _deadPixelIndex++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return PopScope(
      onPopInvokedWithResult: _restoreUiOnPop,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Stack(
          children: [
            Positioned.fill(child: _buildCanvas(context)),
            if (_mode == _ScreenMode.touch)
              Positioned(
                top: MediaQuery.paddingOf(context).top + tokens.space1,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: _TouchCounterBadge(
                      active: _activePointers,
                      max: _maxActivePointers,
                    ),
                  ),
                ),
              ),
            _buildTopChrome(context),
            _buildBottomChrome(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas(BuildContext context) {
    switch (_mode) {
      case _ScreenMode.solid:
        final color = _solidColors[_colorIndex];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _cycleColor();
            _revealChrome();
          },
          child: ColoredBox(
            color: color,
            child: Center(
              child: Text(
                'testers.tapToCycle'.tr,
                style: TextStyle(
                  color: color.computeLuminance() < 0.5
                      ? Colors.white
                      : Colors.black,
                ),
              ),
            ),
          ),
        );
      case _ScreenMode.touch:
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) {
            _onPointerDown(e);
            _revealChrome();
          },
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerUp,
          child: CustomPaint(
            painter: _TouchCanvasPainter(
              repaint: _canvasTick,
              trails: _trails,
              deadlines: _fadeDeadlines,
              fadeDurationMs: _trailFadeDuration.inMilliseconds,
              lineColor: Theme.of(context).colorScheme.onSurface,
            ),
            child: const SizedBox.expand(),
          ),
        );
      case _ScreenMode.deadPixel:
        if (_deadPixelIntro) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _revealChrome,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(context.tokens.space4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: GlassCard(
                    padding: EdgeInsets.all(context.tokens.space3),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.grid_view_outlined,
                          size: 36,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        SizedBox(height: context.tokens.space2),
                        Text(
                          'screenTester.deadPixelIntroTitle'.tr,
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: context.tokens.space1),
                        Text(
                          'screenTester.deadPixelIntro'.tr,
                          style: AppText.muted(context),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: context.tokens.space3),
                        FilledButton.icon(
                          onPressed: () {
                            _advanceDeadPixel();
                            _revealChrome();
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: Text('screenTester.deadPixelStart'.tr),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _advanceDeadPixel();
            _revealChrome();
          },
          child: ColoredBox(color: _deadPixelColors[_deadPixelIndex]),
        );
      case _ScreenMode.gradient:
        return _grayRamp ? const _GrayRampView() : const _GradientSweepView();
    }
  }

  Widget _buildTopChrome(BuildContext context) {
    final tokens = context.tokens;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedSlide(
        offset: _chromeVisible ? Offset.zero : const Offset(0, -1.2),
        duration: tokens.motionMedium,
        curve: AppMotion.curveStandard,
        child: AnimatedOpacity(
          opacity: _chromeVisible ? 1 : 0,
          duration: tokens.motionFast,
          child: IgnorePointer(
            ignoring: !_chromeVisible,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.all(tokens.space2),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Expanded(
                      child: SegmentedButton<_ScreenMode>(
                        showSelectedIcon: false,
                        selected: {_mode},
                        onSelectionChanged: (s) => _setMode(s.first),
                        segments: [
                          ButtonSegment(
                            value: _ScreenMode.solid,
                            icon: const Icon(Icons.palette_outlined),
                            tooltip: 'screenTester.mode.solid'.tr,
                          ),
                          ButtonSegment(
                            value: _ScreenMode.touch,
                            icon: const Icon(Icons.touch_app_outlined),
                            tooltip: 'screenTester.mode.touch'.tr,
                          ),
                          ButtonSegment(
                            value: _ScreenMode.deadPixel,
                            icon: const Icon(Icons.blur_on),
                            tooltip: 'screenTester.mode.deadPixel'.tr,
                          ),
                          ButtonSegment(
                            value: _ScreenMode.gradient,
                            icon: const Icon(Icons.gradient),
                            tooltip: 'screenTester.mode.gradient'.tr,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomChrome(BuildContext context) {
    final tokens = context.tokens;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedSlide(
        offset: _chromeVisible ? Offset.zero : const Offset(0, 1.4),
        duration: tokens.motionMedium,
        curve: AppMotion.curveStandard,
        child: AnimatedOpacity(
          opacity: _chromeVisible ? 1 : 0,
          duration: tokens.motionFast,
          child: IgnorePointer(
            ignoring: !_chromeVisible,
            child: SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  child: GlassCard(
                    margin: EdgeInsets.all(tokens.space2),
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.space3,
                      vertical: tokens.space1,
                    ),
                    child: switch (_mode) {
                      _ScreenMode.solid => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('screenTester.autoCycle'.tr),
                            Switch(
                              value: _autoCycle,
                              onChanged: _toggleAutoCycle,
                            ),
                          ],
                        ),
                      _ScreenMode.touch => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'screenTester.touchHint'.tr,
                                style: AppText.muted(context),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              tooltip: 'screenTester.clearTrails'.tr,
                              onPressed: _clearTrails,
                              icon: const Icon(Icons.cleaning_services_outlined),
                            ),
                          ],
                        ),
                      _ScreenMode.deadPixel => Text(
                          _deadPixelIntro
                              ? 'screenTester.mode.deadPixel'.tr
                              : 'screenTester.deadPixelProgress'.trParams({
                                  'index': '${_deadPixelIndex + 1}',
                                  'total': '${_deadPixelColors.length}',
                                }),
                          style: AppText.numeric(context),
                        ),
                      _ScreenMode.gradient => SegmentedButton<bool>(
                          showSelectedIcon: false,
                          selected: {_grayRamp},
                          onSelectionChanged: (s) {
                            setState(() => _grayRamp = s.first);
                            _revealChrome();
                          },
                          segments: [
                            ButtonSegment(
                              value: false,
                              icon: const Icon(Icons.gradient),
                              label: Text('screenTester.gradientSweep'.tr),
                            ),
                            ButtonSegment(
                              value: true,
                              icon: const Icon(Icons.invert_colors),
                              label: Text('screenTester.grayRamp'.tr),
                            ),
                          ],
                        ),
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TouchCounterBadge extends StatelessWidget {
  const _TouchCounterBadge({required this.active, required this.max});

  final int active;
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Container(
      margin: EdgeInsets.only(top: tokens.space2),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space3,
        vertical: tokens.space1,
      ),
      decoration: ShapeDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.82),
        shape: StadiumBorder(
          side: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.18),
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'screenTester.touches'.trParams({'count': '$active'}),
            style: AppText.numeric(context),
          ),
          SizedBox(width: tokens.space2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: ShapeDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: const StadiumBorder(),
            ),
            child: Text(
              'screenTester.maxTouches'.trParams({'count': '$max'}),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints per-pointer trails: hue per pointer id, fading polyline + dots,
/// crosshairs through each pointer's live position, subtle grid backdrop.
class _TouchCanvasPainter extends CustomPainter {
  _TouchCanvasPainter({
    required ValueListenable<int> repaint,
    required this.trails,
    required this.deadlines,
    required this.fadeDurationMs,
    required this.lineColor,
  }) : super(repaint: repaint);

  final Map<int, List<Offset>> trails;
  final Map<int, DateTime> deadlines;
  final int fadeDurationMs;
  final Color lineColor;

  static const _gridSpacing = 48.0;

  Color _hueFor(int pointer) {
    return HSLColor.fromAHSL(1, (pointer * 67.5) % 360, 0.75, 0.6).toColor();
  }

  double _fadeFor(int pointer, DateTime now) {
    final deadline = deadlines[pointer];
    if (deadline == null) return 1;
    final remaining =
        deadline.difference(now).inMilliseconds / fadeDurationMs;
    return remaining.clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..strokeWidth = 1
      ..color = lineColor.withValues(alpha: 0.05);
    for (var x = _gridSpacing; x < size.width; x += _gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = _gridSpacing; y < size.height; y += _gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final now = DateTime.now();
    trails.forEach((pointer, points) {
      if (points.isEmpty) return;
      final fade = _fadeFor(pointer, now);
      if (fade <= 0) return;
      final baseColor = _hueFor(pointer).withValues(alpha: fade);

      if (points.length > 1) {
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (var i = 1; i < points.length; i++) {
          path.lineTo(points[i].dx, points[i].dy);
        }
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = baseColor,
        );
      }

      final dotPaint = Paint();
      for (var i = 0; i < points.length; i++) {
        final t = points.length == 1 ? 1.0 : i / (points.length - 1);
        dotPaint.color = baseColor.withValues(
          alpha: fade * (0.25 + 0.75 * t),
        );
        canvas.drawCircle(points[i], 2 + 6 * t, dotPaint);
      }

      // Crosshair through the pointer's current position.
      final head = points.last;
      final crossPaint = Paint()
        ..strokeWidth = 1
        ..color = baseColor.withValues(alpha: fade * 0.55);
      canvas.drawLine(
        Offset(0, head.dy),
        Offset(size.width, head.dy),
        crossPaint,
      );
      canvas.drawLine(
        Offset(head.dx, 0),
        Offset(head.dx, size.height),
        crossPaint,
      );
      canvas.drawCircle(
        head,
        12,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = baseColor,
      );
    });
  }

  @override
  bool shouldRepaint(_TouchCanvasPainter oldDelegate) => true;
}

class _GradientSweepView extends StatelessWidget {
  const _GradientSweepView();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red,
            Colors.yellow,
            Colors.green,
            Colors.cyan,
            Colors.blue,
            Colors.purple,
          ],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

class _GrayRampView extends StatelessWidget {
  const _GrayRampView();

  @override
  Widget build(BuildContext context) {
    const steps = 16;
    return Row(
      children: [
        for (var i = 0; i < steps; i++)
          Expanded(
            child: ColoredBox(
              color: Color.lerp(Colors.black, Colors.white, i / (steps - 1))!,
              child: const SizedBox.expand(),
            ),
          ),
      ],
    );
  }
}
