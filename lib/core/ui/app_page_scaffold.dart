import 'package:flutter/material.dart';

import '../theme/theme_tokens.dart';

/// Standard page scaffold: AppBar + consistently padded, safe-area-aware
/// scroll body.
///
/// Pass either [children] (simple ListView) or [slivers] (CustomScrollView)
/// — not both.
class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    required this.title,
    this.actions,
    this.children,
    this.slivers,
    this.floatingActionButton,
    this.bottomNavigationBar,
    super.key,
  }) : assert(
         (children == null) != (slivers == null),
         'Provide either children or slivers, not both',
       );

  final String title;
  final List<Widget>? actions;

  /// Plain scrollable content; padded with [ThemeTokens.space2] plus bottom
  /// safe-area inset.
  final List<Widget>? children;

  /// Slivers wrapped in a [CustomScrollView] with the same padding applied
  /// via [SliverPadding].
  final List<Widget>? slivers;

  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final mediaQuery = MediaQuery.of(context);

    Widget? body;
    if (children != null) {
      body = ListView(
        padding: EdgeInsets.fromLTRB(
          tokens.space2,
          tokens.space2,
          tokens.space2,
          tokens.space2 + mediaQuery.padding.bottom,
        ),
        children: children!,
      );
    } else if (slivers != null) {
      body = CustomScrollView(
        slivers: [
          SliverPadding(padding: EdgeInsets.only(top: tokens.space2)),
          ...slivers!,
          SliverSafeArea(
            sliver: SliverPadding(padding: EdgeInsets.all(tokens.space2)),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
