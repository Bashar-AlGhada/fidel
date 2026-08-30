import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/theme_tokens.dart';
import 'glass_card.dart';
import 'sparkline.dart';

/// Expressive dashboard tile: icon badge, label, big tabular numeric value,
/// optional trend sparkline and tap target.
///
/// Wrap live values with [AppText.heroNumeric]/[AppText.numeric] so digits
/// don't jitter; pass [valueColor] for severity-tinted readouts.
class HeroMetricTile extends StatelessWidget {
  const HeroMetricTile({
    required this.label,
    required this.valueText,
    required this.icon,
    this.onTap,
    this.sparkline,
    this.valueColor,
    this.accent = false,
    super.key,
  });

  final String label;
  final String valueText;
  final IconData icon;
  final VoidCallback? onTap;

  /// Optional trend samples rendered as a fading sparkline along the bottom.
  final List<double>? sparkline;

  /// Overrides the value color (e.g. a token semantic color).
  final Color? valueColor;

  /// Applies the accent gradient tint + highlighted border for hero
  /// emphasis.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return GlassCard(
      onTap: onTap,
      padding: EdgeInsets.all(tokens.space2),
      gradientTint: accent,
      highlightBorder: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: tokens.space4 + 12,
                height: tokens.space4 + 12,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(tokens.radiusMd),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              SizedBox(width: tokens.space2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: tokens.space1 / 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        valueText,
                        style: AppText.heroNumeric(context, color: valueColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (sparkline != null && sparkline!.isNotEmpty) ...[
            SizedBox(height: tokens.space2),
            SizedBox(
              height: tokens.space4,
              width: double.infinity,
              child: Sparkline(data: sparkline!, color: valueColor),
            ),
          ],
        ],
      ),
    );
  }
}
