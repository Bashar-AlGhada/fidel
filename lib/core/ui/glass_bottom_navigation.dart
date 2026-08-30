import 'package:flutter/material.dart';

import '../theme/theme_tokens.dart';
import 'glass_card.dart';

class GlassBottomNavigation extends StatelessWidget {
  const GlassBottomNavigation({
    required this.currentIndex,
    required this.onTap,
    required this.destinations,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<ThemeTokensExtension>()!.tokens;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.grid * 1.5,
        0,
        tokens.grid * 1.5,
        tokens.grid * 1.5,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.radiusLg),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.12),
              blurRadius: tokens.glassBlurSigma,
              offset: Offset(0, tokens.space1 / 2),
            ),
          ],
        ),
        child: GlassCard(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.space1,
            vertical: tokens.grid * 0.75,
          ),
          child: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: onTap,
            destinations: destinations,
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
          ),
        ),
      ),
    );
  }
}
