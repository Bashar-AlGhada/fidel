import 'package:flutter/material.dart';

/// The app's standard determinate meter: an 8 dp pill with a subtle track.
///
/// Use for live ratios (battery %, signal strength, noise level). For
/// indeterminate loading, use `AppLoadingState` or a bare
/// [CircularProgressIndicator] instead.
class AppMeter extends StatelessWidget {
  const AppMeter({required this.value, this.height = 8, super.key});

  /// 0..1, or null for indeterminate animation.
  final double? value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        backgroundColor: Theme.of(
          context,
        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
      ),
    );
  }
}
