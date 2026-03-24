import 'package:flutter/material.dart';

import '../theme/theme_tokens.dart';
import 'glass_card.dart';

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
      padding: padding ?? EdgeInsets.all(tokens.space2),
      child: child,
    );
    return GlassCard(
      margin: margin,
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: content,
    );
  }
}
