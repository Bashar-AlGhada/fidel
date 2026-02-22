import '../../domain/entities/sensors/sensor_accuracy.dart';
import '../../domain/entities/sensors/sensor_capability_entity.dart';
import '../../domain/entities/sensors/sensor_reading_entity.dart';

class SensorEventMapper {
  SensorCapabilityEntity? capabilityFromMap(Map<String, dynamic> map) {
    final key = map['key'];
    final name = map['name'];
    final vendor = map['vendor'];
    final type = map['type'];
    final maxRange = map['maxRange'];
    final resolution = map['resolution'];
    final powerMilliAmp = map['powerMilliAmp'];
    final minDelayUs = map['minDelayUs'];

    return SensorCapabilityEntity(
      key: key is String ? key : '',
      name: name is String ? name : '',
      vendor: vendor is String ? vendor : '',
      type: type is int ? type : (type is num ? type.toInt() : 0),
      maxRange: maxRange is num ? maxRange.toDouble() : 0,
      resolution: resolution is num ? resolution.toDouble() : 0,
      powerMilliAmp: powerMilliAmp is num ? powerMilliAmp.toDouble() : 0,
      minDelay: Duration(
        microseconds: minDelayUs is int
            ? minDelayUs
            : (minDelayUs is num ? minDelayUs.toInt() : 0),
      ),
    );
  }

  SensorReadingEntity? readingFromMap(Map<String, dynamic> map) {
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

  SensorAccuracy? accuracyFromMap(Map<String, dynamic> map) {
    return _accuracyFromRaw(map['accuracy']);
  }

  String? keyFromMap(Map<String, dynamic> map) {
    final key = map['key'];
    return key is String && key.isNotEmpty ? key : null;
  }

  SensorAccuracy? _accuracyFromRaw(Object? raw) {
    final v = raw is int ? raw : (raw is num ? raw.toInt() : null);
    return switch (v) {
      0 => SensorAccuracy.unreliable,
      1 => SensorAccuracy.low,
      2 => SensorAccuracy.medium,
      3 => SensorAccuracy.high,
      _ => null,
    };
  }

  List<double> _parseValues(Object? raw) {
    final list = raw is List ? raw : const [];
    final out = <double>[];
    for (final entry in list) {
      final v = switch (entry) {
        num n => n.toDouble(),
        String s => double.tryParse(s),
        _ => null,
      };
      if (v == null || v.isNaN || v.isInfinite) continue;
      out.add(v);
    }
    return out.toList(growable: false);
  }
}
