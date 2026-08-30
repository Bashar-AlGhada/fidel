import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../application/providers/units_providers.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_tokens.dart';
import '../../../../core/ui/app_card.dart';
import '../../../../core/ui/glass_card.dart';
import '../../../../core/ui/severity_chip.dart';
import '../../../../core/ui/smart_data_display.dart';
import '../../../../domain/entities/info/info_availability.dart';
import '../../../../domain/entities/info/info_item_entity.dart';
import '../../../../domain/entities/info/info_item_value.dart';
import '../../../../domain/entities/info/info_section_entity.dart';
import '../../../../domain/units/measurement_formatter.dart';
import '../../../../domain/units/unit_preferences.dart';
import '../../../../domain/units/units_formatter.dart';

class InfoSection extends ConsumerWidget {
  const InfoSection({required this.section, super.key});

  final InfoSectionEntity section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final items = section.items;
    final prefs = ref
        .watch(unitPreferencesStreamProvider)
        .maybeWhen(data: (p) => p, orElse: () => UnitPreferences.defaults);
    final formatter = ref.watch(unitsFormatterProvider);

    // Runs inside the page's outer scrollable; no own ListView here.
    return Column(
      children: [
        _AvailabilityCard(availability: section.availability),
        SizedBox(height: tokens.space2),
        for (final item in items) ...[
          _InfoItemCard(item: item, prefs: prefs, formatter: formatter),
          SizedBox(height: tokens.space2),
        ],
      ],
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({required this.availability});

  final InfoAvailability availability;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final (icon, textKey, color, level) = switch (availability) {
      InfoAvailability.available => (
          Icons.check_circle,
          'availability.available',
          tokens.successColor,
          SeverityLevel.success,
        ),
      InfoAvailability.unavailable => (
          Icons.warning_amber,
          'availability.unavailable',
          tokens.warningColor,
          SeverityLevel.warning,
        ),
      InfoAvailability.notSupported => (
          Icons.block,
          'availability.notSupported',
          tokens.dangerColor,
          SeverityLevel.danger,
        ),
      InfoAvailability.restricted => (
          Icons.lock,
          'availability.restricted',
          tokens.warningColor,
          SeverityLevel.warning,
        ),
    };

    return GlassCard(
      gradientTint: availability == InfoAvailability.available,
      padding: EdgeInsets.all(tokens.space3),
      child: Row(
        children: [
          Container(
            width: tokens.space4 + 4,
            height: tokens.space4 + 4,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(tokens.radiusMd),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          SizedBox(width: tokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(textKey.tr, style: theme.textTheme.titleMedium),
                SizedBox(height: tokens.space1 / 2),
                Text(
                  availability == InfoAvailability.available
                      ? 'availability.availableHint'.tr
                      : 'availability.unavailableHint'.tr,
                  style: AppText.muted(context),
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.space2),
          SeverityChip(level: level, dot: false, label: textKey.tr),
        ],
      ),
    );
  }
}

class _InfoItemCard extends StatelessWidget {
  const _InfoItemCard({
    required this.item,
    required this.prefs,
    required this.formatter,
  });

  final InfoItemEntity item;
  final UnitPreferences prefs;
  final UnitsFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final available = item.availability == InfoAvailability.available;
    final rawText = item.value?.kind == InfoItemValueKind.text
        ? (item.value?.text ?? '')
        : null;
    final formatted =
        rawText == null ? null : _formatTextValue(item.labelKey, rawText);
    final valueStyle = formatted != null
        ? AppText.numeric(context)
        : theme.textTheme.bodyMedium;

    return AppCard(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space3,
        vertical: tokens.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.labelKey.tr,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (!available)
                Text(
                  _availabilityLabel(item.availability),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
          SizedBox(height: tokens.space1 / 2 + 2),
          if (!available)
            Text(
              'availability.unavailable'.tr,
              style: AppText.muted(context).copyWith(
                fontStyle: FontStyle.italic,
              ),
            )
          else
            _buildValue(context, item, formatted, valueStyle),
        ],
      ),
    );
  }

  Widget _buildValue(
    BuildContext context,
    InfoItemEntity item,
    String? formatted,
    TextStyle? fallbackStyle,
  ) {
    switch (item.value?.kind) {
      case InfoItemValueKind.redacted:
      case InfoItemValueKind.hidden:
        final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
            );
        final text = item.value?.kind == InfoItemValueKind.redacted
            ? 'value.redacted'.tr
            : 'value.hidden'.tr;
        return Text(text, style: style);
      default:
        break;
    }

    final effective = formatted ?? rawTextOf(item);
    final trimmed = effective.trim();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      final decoded = _decodeJson(trimmed);
      if (decoded != null) return SmartDataDisplay(data: decoded);
    }
    return Text(effective, style: fallbackStyle);
  }

  String rawTextOf(InfoItemEntity item) =>
      item.value?.kind == InfoItemValueKind.text ? (item.value?.text ?? '') : '';

  String? _formatTextValue(String labelKey, String raw) {
    if (raw.trim().isEmpty) return null;
    // Refresh rates arrive pre-formatted ('60, 90, 120 Hz'); there is no
    // unit formatter for Hz, so pass the raw string through untouched.
    if (labelKey == 'display.refreshRatesHz') {
      return raw;
    }
    if (labelKey.endsWith('Bytes')) {
      final bytes = int.tryParse(raw);
      if (bytes == null) return null;
      return formatter.formatBytes(bytes: bytes, base: prefs.dataSizeBase);
    }
    if (labelKey.endsWith('temperatureC') || labelKey.endsWith('TempC')) {
      final c = double.tryParse(raw);
      if (c == null) return null;
      return formatter.formatTemperature(celsius: c, unit: prefs.temperature);
    }
    if (labelKey.endsWith('voltageMv')) {
      final mv = double.tryParse(raw);
      if (mv == null) return null;
      return formatter.formatMillivolts(millivolts: mv);
    }
    if (labelKey.endsWith('currentNowUa') ||
        labelKey.endsWith('currentAverageUa')) {
      final ua = double.tryParse(raw);
      if (ua == null) return null;
      return formatter.formatElectricCurrent(microAmps: ua);
    }
    // Plain measured numbers (px, dpi, densities) go through the shared
    // measurement formatter for consistent rendering.
    if (_isPlainMetricLabel(labelKey)) {
      final n = double.tryParse(raw);
      if (n != null && n.isFinite) return formatMeasurement(n);
    }
    return null;
  }

  bool _isPlainMetricLabel(String labelKey) =>
      labelKey.endsWith('Px') ||
      labelKey.endsWith('Dpi') ||
      labelKey == 'display.density' ||
      labelKey == 'display.scaledDensity';

  Object? _decodeJson(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  String _availabilityLabel(InfoAvailability availability) {
    return switch (availability) {
      InfoAvailability.available => 'availability.available'.tr,
      InfoAvailability.unavailable => 'availability.unavailable'.tr,
      InfoAvailability.notSupported => 'availability.notSupported'.tr,
      InfoAvailability.restricted => 'availability.restricted'.tr,
    };
  }
}
