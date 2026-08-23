import '../../domain/entities/sensors/sensor_accuracy.dart';
import '../../domain/entities/sensors/sensor_capability_entity.dart';
import '../../domain/entities/sensors/sensor_reading_entity.dart';
import '../../core/utils/map_coercion.dart';

class SensorEventMapper {
  SensorCapabilityEntity capabilityFromMap(Map<String, dynamic> map) {
    return SensorCapabilityEntity(
      key: map['key'] is String ? map['key'] as String : '',
      name: map['name'] is String ? map['name'] as String : '',
      vendor: map['vendor'] is String ? map['vendor'] as String : '',
      type: coerceInt(map['type'], fallback: 0),
      maxRange: coerceDouble(map['maxRange'], fallback: 0),
      resolution: coerceDouble(map['resolution'], fallback: 0),
      powerMilliAmp: coerceDouble(map['powerMilliAmp'], fallback: 0),
      minDelay: Duration(
        microseconds: coerceInt(map['minDelayUs'], fallback: 0),
      ),
    );
  }

  SensorReadingEntity readingFromMap(Map<String, dynamic> map) {
    final timestampMs = map['timestampMs'];
    final values = map['values'];
    final accuracy = map['accuracy'];

    final ts = timestampMs is int
        ? DateTime.fromMillisecondsSinceEpoch(timestampMs)
        : (timestampMs is num
              ? DateTime.fromMillisecondsSinceEpoch(timestampMs.toInt())
              : DateTime.now());

    final parsedValues = _parseValues(values);

    return SensorReadingEntity(
      timestamp: ts,
      values: parsedValues,
      accuracy: _accuracyFromRaw(accuracy),
    );
  }

  String? keyFromMap(Map<String, dynamic> map) {
    final key = map['key'];
    return key is String && key.isNotEmpty ? key : null;
  }

  /// Accepts both the native int code (0-3) and the persisted enum name.
  SensorAccuracy? _accuracyFromRaw(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      for (final a in SensorAccuracy.values) {
        if (a.name == raw) return a;
      }
      return null;
    }
    final v = raw is int ? raw : (raw is num ? raw.toInt() : null);
    return switch (v) {
      0 => SensorAccuracy.unreliable,
      1 => SensorAccuracy.low,
      2 => SensorAccuracy.medium,
      3 => SensorAccuracy.high,
      _ => null,
    };
  }

  /// Preserves value positions: unparsable/invalid entries become [double.nan]
  /// rather than being dropped, so axis indices stay aligned with the
  /// sensor's channel layout. The chart skips NaN points when drawing.
  List<double> _parseValues(Object? raw) {
    final list = raw is List ? raw : const [];
    return List<double>.unmodifiable(
      list.map(
        (entry) => switch (entry) {
          num n => n.toDouble(),
          String s => double.tryParse(s) ?? double.nan,
          _ => double.nan,
        },
      ),
    );
  }
}
