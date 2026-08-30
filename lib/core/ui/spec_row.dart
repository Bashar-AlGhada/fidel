import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/theme_tokens.dart';

/// Label/value row for spec sheets; renders nothing when [value] is blank.
///
/// Canonical implementation (previously duplicated in
/// `features/sections/presentation/widgets/section_cards.dart`).
class SpecRow extends StatelessWidget {
  const SpecRow({
    required this.label,
    required this.value,
    this.valueStyle,
    this.trailing,
    this.numeric = false,
    super.key,
  });

  final String label;
  final String? value;

  /// Optional override for the value's text style.
  final TextStyle? valueStyle;

  /// Optional widget after the value (e.g. a copy button or severity chip).
  final Widget? trailing;

  /// Renders the value with the tabular-figure readout style, keeping
  /// changing digits visually stable.
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.trim().isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final style =
        valueStyle ??
        (numeric
            ? AppText.numeric(context)
            : theme.textTheme.bodyMedium);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.space1 / 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 110),
            child: Text(
              label,
              style: AppText.muted(context),
            ),
          ),
          SizedBox(width: tokens.space1),
          Expanded(
            child: Text(value!, style: style),
          ),
          if (trailing != null) ...[
            SizedBox(width: tokens.space1),
            trailing!,
          ],
        ],
      ),
    );
  }
}
