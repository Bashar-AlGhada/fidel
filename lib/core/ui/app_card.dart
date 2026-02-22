import 'package:flutter/material.dart';

import '../theme/theme_tokens.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ThemeTokensExtension>()!.tokens;
    final content = Padding(
      padding: padding ?? EdgeInsets.all(tokens.space3),
      child: child,
    );

    if (onTap == null) {
      return Card(
        margin: margin,
        child: content,
      );
    }

    return Card(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: tokens.cardBorderRadius,
        onTap: onTap,
        child: content,
      ),
    );
  }
}
