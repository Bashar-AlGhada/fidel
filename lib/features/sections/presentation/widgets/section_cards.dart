import 'package:flutter/material.dart';

/// Filter chip used by metadata section pages (cameras, codecs, ...).
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
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Chip(
        visualDensity: VisualDensity.compact,
        label: Text(label),
        backgroundColor: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
      ),
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
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label: $value', style: theme.textTheme.labelLarge),
    );
  }
}

/// Label/value row for spec sheets; renders nothing when [value] is blank.
class SpecRow extends StatelessWidget {
  const SpecRow({required this.label, required this.value, super.key});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label)),
          const SizedBox(width: 8),
          Expanded(child: Text(value!)),
        ],
      ),
    );
  }
}
