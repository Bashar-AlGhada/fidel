import 'dart:convert';

import '../../../../core/logging/app_logger.dart';

/// Normalizes thermal JSON (list or keyed map) into row maps.
List<Map<String, dynamic>> normalizeThermalPayload(Object? decoded) {
  return switch (decoded) {
    List list =>
      list
          .whereType<Map>()
          .map((entry) => entry.cast<String, dynamic>())
          .toList(growable: false),
    Map map =>
      map.entries
          .map((entry) {
            final value = entry.value;
            if (value is Map) return value.cast<String, dynamic>();
            return <String, dynamic>{'name': entry.key, 'valueC': value};
          })
          .toList(growable: false),
    _ => const [],
  };
}

/// Extracts a finite celsius reading from a thermal row, if any.
double? temperatureValueOf(Map<String, dynamic> row) {
  final value = row['valueC'] ?? row['value'] ?? row['tempC'] ?? row['celsius'];
  final numValue = switch (value) {
    num v => v.toDouble(),
    String v => double.tryParse(v),
    _ => null,
  };
  if (numValue == null || numValue.isNaN || numValue.isInfinite) return null;
  return numValue;
}

/// Highest finite temperature in a serialized thermal payload.
double? maxTemperatureFromRaw(String raw) {
  try {
    double? max;
    for (final row in normalizeThermalPayload(jsonDecode(raw))) {
      final v = temperatureValueOf(row);
      if (v == null) continue;
      max = max == null ? v : (v > max ? v : max);
    }
    return max;
  } catch (e, st) {
    AppLog.warn('Failed to parse thermal payload', error: e, stackTrace: st);
    return null;
  }
}
