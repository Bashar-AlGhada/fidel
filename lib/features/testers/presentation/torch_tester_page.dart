import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_page_scaffold.dart';
import '../../../core/ui/app_states.dart';
import '../../../core/ui/glass_card.dart';
import '../../../platform/android_bridge.dart';
import 'widgets/native_result.dart';

class TorchTesterPage extends StatefulWidget {
  const TorchTesterPage({super.key});

  @override
  State<TorchTesterPage> createState() => _TorchTesterPageState();
}

class _TorchTesterPageState extends State<TorchTesterPage> {
  static const _halfPeriodFloorMs = 25;

  bool _on = false;
  bool _busy = false;
  bool _hardwareMissing = false;

  double _strobeHz = 5;
  bool _strobing = false;
  Timer? _strobeTimer;

  @override
  void dispose() {
    _strobeTimer?.cancel();
    if (_on || _strobing) {
      unawaited(AndroidBridge.setTorch(enabled: false));
    }
    super.dispose();
  }

  String _reasonMessage(String? reason) => switch (reason) {
        'torch_unavailable' || 'unsupported_platform' || 'missing_plugin' =>
          'torch.reason.torch_unavailable'.tr,
        'camera_error' => 'torch.reason.camera_error'.tr,
        _ => 'torch.reason.failed'.tr,
      };

  Future<void> _apply(bool enabled) async {
    if (_busy) return;
    _busy = true;
    final result = await AndroidBridge.setTorch(enabled: enabled);
    _busy = false;
    if (!mounted) return;

    final (:ok, :reason) = decodeNativeResult(result);
    setState(() {
      if (ok) {
        _on = enabled;
        _hardwareMissing = false;
      } else {
        _hardwareMissing =
            reason == 'torch_unavailable' ||
            reason == 'unsupported_platform' ||
            reason == 'missing_plugin';
      }
    });

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_reasonMessage(reason))),
      );
    }
  }

  void _startStrobe() {
    _strobeTimer?.cancel();
    setState(() => _strobing = true);
    _scheduleStrobeTick();
  }

  void _scheduleStrobeTick() {
    final halfPeriodMs =
        ((1000 / _strobeHz) / 2).round().clamp(_halfPeriodFloorMs, 1000);
    _strobeTimer = Timer(Duration(milliseconds: halfPeriodMs), _strobeTick);
  }

  Future<void> _strobeTick() async {
    if (!mounted || !_strobing) return;
    final next = !_on;
    await _apply(next);
    if (!mounted || !_strobing || _hardwareMissing) {
      if (mounted && _strobing) _stopStrobe();
      return;
    }
    _scheduleStrobeTick();
  }

  void _stopStrobe() {
    _strobeTimer?.cancel();
    _strobeTimer = null;
    setState(() => _strobing = false);
  }

  void _toggleStrobe() {
    if (_strobing) {
      _stopStrobe();
      return;
    }
    _startStrobe();
  }

  void _updateHz(double hz) {
    setState(() => _strobeHz = hz);
    if (_strobing && !_busy) {
      _strobeTimer?.cancel();
      _scheduleStrobeTick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return AppPageScaffold(
      title: 'testers.torchTester'.tr,
      children: [
        if (_hardwareMissing)
          AppEmptyState(
            icon: Icons.flashlight_off_outlined,
            title: 'torch.hardwareMissingTitle'.tr,
            message: 'torch.reason.torch_unavailable'.tr,
            actionLabel: 'action.retry'.tr,
            onAction: () => setState(() => _hardwareMissing = false),
          )
        else ...[
          Center(
            child: Column(
              children: [
                SizedBox(
                  width: 148,
                  height: 148,
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor: _on
                          ? tokens.warningColor.withValues(alpha: 0.28)
                          : null,
                    ),
                    onPressed: _busy ? null : () => _apply(!_on),
                    child: Icon(
                      _on ? Icons.flashlight_on : Icons.flashlight_off,
                      size: 56,
                      color: _on ? tokens.warningColor : null,
                    ),
                  ),
                ),
                SizedBox(height: tokens.space2),
                Text(
                  _on ? 'torch.toggleOn'.tr : 'torch.toggleOff'.tr,
                  style: AppText.numeric(context),
                ),
              ],
            ),
          ),
          SizedBox(height: tokens.space3),
          GlassCard(
            padding: EdgeInsets.all(tokens.space3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child:
                          Text('torch.strobe'.tr, style: AppText.numeric(context)),
                    ),
                    Text(
                      'torch.frequency'.trParams({
                        'value': _strobeHz.toStringAsFixed(0),
                      }),
                      style: AppText.muted(context),
                    ),
                  ],
                ),
                Slider(
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '${_strobeHz.toStringAsFixed(0)} Hz',
                  value: _strobeHz,
                  onChanged: _updateHz,
                ),
                FilledButton.tonalIcon(
                  onPressed: _toggleStrobe,
                  icon: Icon(_strobing ? Icons.stop : Icons.bolt),
                  label: Text(
                    _strobing ? 'torch.stopStrobe'.tr : 'torch.startStrobe'.tr,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
