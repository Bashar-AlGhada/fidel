import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_page_scaffold.dart';
import '../../../core/ui/glass_card.dart';
import '../../../platform/android_bridge.dart';
import 'widgets/native_result.dart';

class _PatternSpec {
  const _PatternSpec(
    this.labelKey,
    this.icon,
    this.patternMs, [
    this.amplitudes,
  ]);

  final String labelKey;
  final IconData icon;
  final List<int> patternMs;
  final List<int>? amplitudes;
}

class VibrationTesterPage extends StatefulWidget {
  const VibrationTesterPage({super.key});

  @override
  State<VibrationTesterPage> createState() => _VibrationTesterPageState();
}

class _VibrationTesterPageState extends State<VibrationTesterPage> {
  static final List<_PatternSpec> _patterns = [
    _PatternSpec('vibration.patternShort', Icons.touch_app, [0, 50]),
    _PatternSpec('vibration.patternLong', Icons.vibration, [0, 500]),
    _PatternSpec('vibration.patternDouble', Icons.double_arrow, [
      50,
      100,
      50,
      100,
    ]),
    _PatternSpec('vibration.patternRamp', Icons.graphic_eq, [
      0,
      100,
      80,
      100,
      60,
      100,
      40,
      100,
    ]),
    _PatternSpec('vibration.patternAmplitude', Icons.equalizer, [
      0,
      200,
      150,
      200,
    ], [
      30,
      255,
    ]),
  ];

  String? _firingKey;
  _Feedback _feedback = _Feedback.idle();

  Future<void> _fire(_PatternSpec spec) async {
    if (_firingKey != null) return;
    setState(() {
      _firingKey = spec.labelKey;
      _feedback = _Feedback.running();
    });

    final result = await AndroidBridge.testVibration(
      patternMs: spec.patternMs,
      amplitudes: spec.amplitudes,
    );
    if (!mounted) return;

    String reasonMessage(String? reason) => switch (reason) {
          'unsupported' ||
          'unsupported_platform' ||
          'missing_plugin' => 'vibration.reason.unsupported'.tr,
          'permission_denied' => 'vibration.reason.permission_denied'.tr,
          'invalid_args' => 'vibration.reason.invalid_args'.tr,
          _ => 'vibration.reason.failed'.tr,
        };

    final payload = decodeNativeResult(result);
    setState(() {
      _firingKey = null;
      _feedback = payload.ok
          ? _Feedback.success()
          : _Feedback.failure(reasonMessage(payload.reason));
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return AppPageScaffold(
      title: 'testers.vibrationTester'.tr,
      children: [
        Text('vibration.tapHint'.tr, style: AppText.muted(context)),
        SizedBox(height: tokens.space2),
        GlassCard(
          padding: EdgeInsets.all(tokens.space2),
          child: AnimatedSwitcher(
            duration: tokens.motionFast,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: _buildFeedback(context),
          ),
        ),
        SizedBox(height: tokens.space2),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = ((constraints.maxWidth - tokens.space2) / 2)
                .clamp(140.0, 240.0);
            return Wrap(
              spacing: tokens.space2,
              runSpacing: tokens.space2,
              children: [
                for (final spec in _patterns)
                  SizedBox(
                    width: width,
                    height: tokens.space4 + 32,
                    child: FilledButton.tonalIcon(
                      onPressed:
                          _firingKey == null ? () => _fire(spec) : null,
                      icon: Icon(spec.icon),
                      label: Text(
                        spec.labelKey.tr,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        SizedBox(height: tokens.space1),
        Text(
          'vibration.amplitudeHint'.tr,
          style: AppText.muted(context),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFeedback(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final feedback = _feedback;

    final Widget content;
    switch (feedback.kind) {
      case _FeedbackKind.idle:
        content = Row(
          children: [
            Icon(
              Icons.info_outline,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: tokens.space2),
            Expanded(child: Text('vibration.tapHint'.tr)),
          ],
        );
      case _FeedbackKind.running:
        content = Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: tokens.space2),
            Expanded(
              child: Text(
                _feedback.label ?? '',
                style: AppText.numeric(context),
              ),
            ),
          ],
        );
      case _FeedbackKind.success:
        content = Row(
          children: [
            Icon(Icons.check_circle_outline, color: tokens.successColor),
            SizedBox(width: tokens.space2),
            Expanded(
              child: Text(
                'vibration.ok'.tr,
                style: AppText.numeric(context, color: tokens.successColor),
              ),
            ),
          ],
        );
      case _FeedbackKind.failure:
        content = Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            SizedBox(width: tokens.space2),
            Expanded(
              child: Text(
                _feedback.label ?? '',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        );
    }
    return KeyedSubtree(
      key: ValueKey(feedback.kind),
      child: content,
    );
  }
}

enum _FeedbackKind { idle, running, success, failure }

class _Feedback {
  const _Feedback._(this.kind, this.label);

  factory _Feedback.idle() => const _Feedback._(_FeedbackKind.idle, null);
  factory _Feedback.success() =>
      const _Feedback._(_FeedbackKind.success, null);
  factory _Feedback.failure(String message) =>
      _Feedback._(_FeedbackKind.failure, message);
  factory _Feedback.running([String? label]) =>
      _Feedback._(_FeedbackKind.running, label);

  final _FeedbackKind kind;
  final String? label;
}
