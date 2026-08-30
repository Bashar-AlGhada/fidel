import 'package:flutter/material.dart';

TextTheme buildAppTextTheme(TextTheme base) {
  return base.copyWith(
    displaySmall: base.displaySmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
    titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: base.bodyLarge?.copyWith(height: 1.35),
    bodyMedium: base.bodyMedium?.copyWith(height: 1.35),
    labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  );
}

/// Static typography helpers for the app's expressive scale.
///
/// Prefer these over ad-hoc `copyWith` chains so numeric readouts stay
/// aligned and hero numbers stay consistent across pages.
abstract final class AppText {
  /// Readout style for live data: tabular figures, slightly larger, w600.
  ///
  /// Use for any value that updates in place (percentages, counters, rates)
  /// so digits don't jitter as they change.
  static TextStyle numeric(BuildContext context, {Color? color}) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16);
    return body.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: color,
    );
  }

  /// Hero readout style: [displaySmall] with tighter spacing and tabular
  /// figures, for big dashboard values.
  static TextStyle heroNumeric(BuildContext context, {Color? color}) {
    final theme = Theme.of(context);
    final display = theme.textTheme.displaySmall;
    return (display ??
            const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ))
        .copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
          color: color,
        );
  }

  /// Muted supporting text (captions, hints) using onSurfaceVariant.
  static TextStyle muted(BuildContext context) {
    return Theme.of(
      context,
    ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
  }
}
