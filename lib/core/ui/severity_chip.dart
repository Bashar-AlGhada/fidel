import 'package:flutter/material.dart';

import '../theme/theme_tokens.dart';

/// Semantic severity levels mapped to token colors.
enum SeverityLevel { success, warning, danger, info }

/// Small semantic pill: colored dot + label, tinted with the level's
/// token color (success/warning/danger from [ThemeTokens], info = primary).
class SeverityChip extends StatelessWidget {
  const SeverityChip({
    required this.level,
    required this.label,
    this.dot = true,
    super.key,
  });

  final SeverityLevel level;
  final String label;

  /// Whether to render the leading status dot. Defaults to true.
  final bool dot;

  Color _color(BuildContext context) {
    final tokens = context.tokens;
    switch (level) {
      case SeverityLevel.success:
        return tokens.successColor;
      case SeverityLevel.warning:
        return tokens.warningColor;
      case SeverityLevel.danger:
        return tokens.dangerColor;
      case SeverityLevel.info:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.14),
        shape: StadiumBorder(
          side: BorderSide(color: color.withValues(alpha: 0.35)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            CircleAvatar(radius: 3.5, backgroundColor: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
