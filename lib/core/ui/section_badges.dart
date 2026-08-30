import 'package:flutter/material.dart';

import '../theme/theme_tokens.dart';

/// Filter chip used by metadata section pages (cameras, codecs, ...).
///
/// Canonical implementation (moved from
/// `features/sections/presentation/widgets/section_cards.dart`); the
/// selected state now uses an accent-gradient border.
class SectionFilterChip extends StatelessWidget {
  const SectionFilterChip({
    required this.selected,
    required this.label,
    required this.onTap,
    super.key,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final shape = StadiumBorder(
      side: BorderSide(
        color: selected
            ? Colors.transparent
            : theme.colorScheme.outlineVariant,
      ),
    );

    Widget chip = Material(
      color: selected ? Colors.transparent : theme.colorScheme.surfaceContainer,
      shape: shape,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected ? theme.colorScheme.onSurface : null,
            ),
          ),
        ),
      ),
    );

    if (selected) {
      // Gradient ring drawn around a translucent pill keeps the glass feel.
      chip = DecoratedBox(
        decoration: ShapeDecoration(
          gradient: tokens.accentGradient,
          shape: const StadiumBorder(),
        ),
        child: Padding(
          padding: EdgeInsets.all(tokens.strokeWidth),
          child: Material(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.85,
            ),
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(label, style: theme.textTheme.labelLarge),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      selected: selected,
      child: chip,
    );
  }
}

/// Pill showing a `label: value` summary count.
class SectionSummaryBadge extends StatelessWidget {
  const SectionSummaryBadge({
    required this.label,
    required this.value,
    super.key,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: ShapeDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        shape: StadiumBorder(
          side: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        style: theme.textTheme.labelLarge,
      ),
    );
  }
}
