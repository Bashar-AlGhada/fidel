import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../core/theme/theme_tokens.dart'
    show ThemeTokensContext;
import '../../../../../core/ui/severity_chip.dart';

/// Maps a thermal status word onto shared semantic levels
/// (none/light -> info, moderate -> warning, severe+ -> danger).
SeverityLevel thermalSeverityForWord(String? word) => switch (word) {
      'moderate' => SeverityLevel.warning,
      'severe' || 'critical' || 'emergency' || 'shutdown' => SeverityLevel.danger,
      _ => SeverityLevel.info,
    };

/// Token color for a semantic level.
Color? thermalTokenColor(BuildContext context, SeverityLevel level) =>
    switch (level) {
      SeverityLevel.success => context.tokens.successColor,
      SeverityLevel.warning => context.tokens.warningColor,
      SeverityLevel.danger => context.tokens.dangerColor,
      SeverityLevel.info => Theme.of(context).colorScheme.primary,
    };

/// Localized thermal status word with graceful fallback to the raw word.
String thermalStatusLabel(String word) {
  final key = 'thermal.status.$word';
  final translated = key.tr;
  return translated == key ? word : translated;
}
