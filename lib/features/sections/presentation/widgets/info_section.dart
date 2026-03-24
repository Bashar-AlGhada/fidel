import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../application/providers/units_providers.dart';
import '../../../../domain/entities/info/info_availability.dart';
import '../../../../domain/entities/info/info_item_entity.dart';
import '../../../../domain/entities/info/info_item_value.dart';
import '../../../../domain/entities/info/info_section_entity.dart';
import '../../../../domain/units/unit_preferences.dart';
import '../../../../domain/units/units_formatter.dart';

class InfoSection extends ConsumerWidget {
  const InfoSection({required this.section, super.key});

  final InfoSectionEntity section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = section.items;
    final prefs = ref.watch(unitPreferencesStreamProvider).maybeWhen(data: (p) => p, orElse: () => UnitPreferences.defaults);
    final formatter = ref.watch(unitsFormatterProvider);

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.isEmpty ? 1 : items.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _AvailabilityCard(availability: section.availability);
        }
        final item = items[index - 1];
        return _InfoItemCard(item: item, prefs: prefs, formatter: formatter);
      },
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({required this.availability});

  final InfoAvailability availability;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, textKey, color) = switch (availability) {
      InfoAvailability.available => (Icons.check_circle, 'availability.available', Colors.green),
      InfoAvailability.unavailable => (Icons.warning_amber, 'availability.unavailable', Colors.orange),
      InfoAvailability.notSupported => (Icons.block, 'availability.notSupported', Colors.red),
      InfoAvailability.restricted => (Icons.lock, 'availability.restricted', Colors.orange),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(textKey.tr, style: theme.textTheme.titleMedium),
        subtitle: availability == InfoAvailability.available ? Text('availability.availableHint'.tr) : Text('availability.unavailableHint'.tr),
      ),
    );
  }
}

class _InfoItemCard extends StatelessWidget {
  const _InfoItemCard({required this.item, required this.prefs, required this.formatter});

  final InfoItemEntity item;
  final UnitPreferences prefs;
  final UnitsFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final (valueText, valueStyle) = _renderValue(context, item);
    final availabilityText = item.availability == InfoAvailability.available ? null : _availabilityLabel(item.availability);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: ListTile(
          title: Text(item.labelKey.tr),
          subtitle: valueText == null ? Text(availabilityText ?? 'availability.unavailable'.tr) : Text(valueText, style: valueStyle),
          trailing: availabilityText == null ? null : Text(availabilityText, style: Theme.of(context).textTheme.labelMedium),
        ),
      ),
    );
  }

  (String?, TextStyle?) _renderValue(BuildContext context, InfoItemEntity item) {
    final theme = Theme.of(context);
    final value = item.value;
    if (value == null) return (null, null);
    return switch (value.kind) {
      InfoItemValueKind.text => (_formatTextValue(item.labelKey, value.text ?? '') ?? (value.text ?? ''), theme.textTheme.bodyMedium),
      InfoItemValueKind.redacted => ('value.redacted'.tr, theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
      InfoItemValueKind.hidden => ('value.hidden'.tr, theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
    };
  }

  String? _formatTextValue(String labelKey, String raw) {
    if (raw.trim().isEmpty) return null;
    final parsedJson = _formatJsonText(raw);
    if (parsedJson != null) return parsedJson;
    if (labelKey == 'display.refreshRatesHz') {
      return raw;
    }
    if (labelKey.contains('Bytes') || labelKey.endsWith('Bytes')) {
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
      return '${(mv / 1000.0).toStringAsFixed(3)} V';
    }
    if (labelKey.endsWith('currentNowUa') || labelKey.endsWith('currentAverageUa')) {
      final ua = double.tryParse(raw);
      if (ua == null) return null;
      return formatter.formatElectricCurrent(microAmps: ua);
    }
    return null;
  }

  String? _formatJsonText(String raw) {
    final trimmed = raw.trim();
    if (!(trimmed.startsWith('{') || trimmed.startsWith('['))) return null;

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final entries = decoded.entries
            .map((entry) {
              final value = _compactJsonValue(entry.value);
              return '${entry.key}: $value';
            })
            .toList(growable: false);
        return entries.join('\n');
      }

      if (decoded is List) {
        if (decoded.isEmpty) return '[]';
        if (decoded.every((e) => e is num || e is bool || e is String)) {
          return decoded.join(', ');
        }
        return 'List (${decoded.length} items)';
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  String _compactJsonValue(Object? value) {
    return switch (value) {
      null => 'null',
      String v => v,
      num v => v.toString(),
      bool v => v.toString(),
      Map v => 'Map (${v.length} fields)',
      List v => 'List (${v.length} items)',
      _ => value.toString(),
    };
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
