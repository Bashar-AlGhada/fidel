import '../../domain/entities/battery_entity.dart';
import '../../core/utils/map_coercion.dart';

class BatteryMapper {
  const BatteryMapper();

  BatteryEntity fromMap(Map<String, dynamic> map) {
    final percent = coerceInt(map['percent'], fallback: 0).clamp(0, 100);

    double? finite(Object? raw) {
      final v = coerceDouble(raw, fallback: double.nan);
      return v.isFinite ? v : null;
    }

    bool? flag(Object? raw) => raw is bool ? raw : null;

    return BatteryEntity(
      percent: percent,
      voltageV: finite(map['voltageV']),
      currentMicroAmps: finite(map['currentMicroAmps']),
      temperatureC: finite(map['temperatureC']),
      capacityMah: finite(map['capacityMah']),
      charging: flag(map['charging']),
      plugged: flag(map['plugged']),
      watts: finite(map['watts']),
    );
  }
}
