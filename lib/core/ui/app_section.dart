import 'package:flutter/material.dart';

import '../theme/theme_tokens.dart';

class AppSection extends StatelessWidget {
  const AppSection({
    required this.title,
    this.subtitle,
    this.trailing,
    this.child,
    this.padding,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<ThemeTokensExtension>()!.tokens;

    return Padding(
      padding: padding ?? EdgeInsets.all(tokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
          if (child != null) ...[
            SizedBox(height: tokens.space3),
            child!,
          ],
        ],
      ),
    );
  }
}
