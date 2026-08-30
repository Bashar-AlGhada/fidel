import '../../domain/entities/battery_entity.dart';
import '../../core/utils/map_coercion.dart';

class BatteryMapper {
  const BatteryMapper();

  /// Legacy OEMs deliver sentinel magnitudes (e.g. INT_MIN) through the
  /// µA fields; anything past ±100 A is garbage, not a reading.
  static const int _maxPlausibleMicroAmps = 100000000;

  BatteryEntity fromMap(Map<String, dynamic> map) {
    final percent = coerceInt(map['percent'], fallback: 0).clamp(0, 100);

    double? finite(Object? raw) {
      final v = coerceDouble(raw, fallback: double.nan);
      return v.isFinite ? v : null;
    }

    bool? flag(Object? raw) => raw is bool ? raw : null;

    String? text(Object? raw) => raw is String && raw.isNotEmpty ? raw : null;

    int? microAmps(Object? raw) {
      final v = coerceInt(raw, fallback: 0);
      return v.abs() > _maxPlausibleMicroAmps ? null : v;
    }

    return BatteryEntity(
      percent: percent,
      voltageV: finite(map['voltageV']),
      currentMicroAmps: finite(map['currentMicroAmps']),
      averageCurrentMicroAmps: microAmps(map['averageCurrentMicroAmps']),
      temperatureC: finite(map['temperatureC']),
      capacityMah: finite(map['capacityMah']),
      chargeCounterUah: microAmps(map['chargeCounterUah']),
      // Energy counters legitimately exceed 1e8 nWh on large packs, so
      // only type-coercion guards this one.
      energyCounterNwh: map['energyCounterNwh'] == null
          ? null
          : coerceInt(map['energyCounterNwh'], fallback: 0),
      charging: flag(map['charging']),
      plugged: flag(map['plugged']),
      plugSource: text(map['plugSource']),
      status: text(map['status']),
      health: text(map['health']),
      watts: finite(map['watts']),
    );
  }
}
