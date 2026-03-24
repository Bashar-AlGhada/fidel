import '../../domain/entities/cpu_entity.dart';
import '../../domain/value_objects/percentage.dart';

class CpuMapper {
  CpuEntity fromMap(Map<String, dynamic> map) {
    final hasData = map.isNotEmpty;
    if (!hasData) {
      return CpuEntity(usage: Percentage.fromRatio(0), cores: 1);
    }

    final ratio = map['usageRatio'];
    final cores = map['cores'];

    final ratioValue = switch (ratio) {
      num v => v.toDouble(),
      String v => double.tryParse(v) ?? 0.0,
      _ => 0.0,
    };

    final parsedCores = switch (cores) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v) ?? 0,
      _ => 0,
    };
    final coresValue = parsedCores <= 0 ? 1 : parsedCores;

    return CpuEntity(
      usage: Percentage.fromRatio(ratioValue),
      cores: coresValue,
    );
  }
}
