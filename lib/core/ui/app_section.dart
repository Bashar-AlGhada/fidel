import 'package:flutter/material.dart';

import '../theme/theme_tokens.dart';

class AppSection extends StatelessWidget {
  const AppSection({
    required this.title,
    this.subtitle,
    this.trailing,
    this.child,
    this.padding,
    this.icon,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? child;
  final EdgeInsetsGeometry? padding;

  /// Optional small icon rendered in a primary-container badge before the
  /// title.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<ThemeTokensExtension>()!.tokens;

    return Padding(
      padding: padding ?? EdgeInsets.all(tokens.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: tokens.space4,
                  height: tokens.space4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                SizedBox(width: tokens.space2),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    if (subtitle != null) ...[
                      SizedBox(height: tokens.space1),
                      Text(subtitle!, style: theme.textTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: tokens.space2),
                trailing!,
              ],
            ],
          ),
          if (child != null) ...[SizedBox(height: tokens.space2), child!],
        ],
      ),
    );
  }
}
