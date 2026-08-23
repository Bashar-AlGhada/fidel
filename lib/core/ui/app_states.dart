import 'package:flutter/material.dart';

import '../theme/theme_tokens.dart';

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<ThemeTokensExtension>()!.tokens;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              SizedBox(height: tokens.space3),
              Text(message!, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.filledAction,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final bool filledAction;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<ThemeTokensExtension>()!.tokens;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: EdgeInsets.all(tokens.space4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxHeight.isFinite && constraints.maxHeight < 140;
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: compact ? 36 : 48, color: iconColor),
                    SizedBox(height: compact ? tokens.space2 : tokens.space3),
                    Text(title, style: theme.textTheme.titleMedium),
                    if (!compact && message != null) ...[
                      SizedBox(height: tokens.space2),
                      Text(
                        message!,
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (!compact &&
                        actionLabel != null &&
                        onAction != null) ...[
                      SizedBox(height: tokens.space3),
                      if (filledAction)
                        FilledButton(
                          onPressed: onAction,
                          child: Text(actionLabel!),
                        )
                      else
                        OutlinedButton(
                          onPressed: onAction,
                          child: Text(actionLabel!),
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.title,
    this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _StateCard(
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      icon: icon ?? Icons.inbox_outlined,
      iconColor: theme.colorScheme.onSurfaceVariant,
      filledAction: true,
    );
  }
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _StateCard(
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      icon: Icons.error_outline,
      iconColor: theme.colorScheme.error,
      filledAction: false,
    );
  }
}
