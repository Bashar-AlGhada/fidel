import '../../domain/entities/battery_entity.dart';

class BatteryMapper {
  BatteryEntity fromMap(Map<String, dynamic> map) {
    final raw = map['percent'];
    final percent = switch (raw) {
      int v => v,
      num v => v.round(),
      String v => int.tryParse(v) ?? 0,
      _ => 0,
    };

    return BatteryEntity(percent: percent.clamp(0, 100));
  }
}
