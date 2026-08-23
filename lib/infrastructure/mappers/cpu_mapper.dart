import '../../core/logging/app_logger.dart';
import '../../domain/entities/cpu_entity.dart';
import '../../domain/value_objects/percentage.dart';
import '../../core/utils/map_coercion.dart';

class CpuMapper {
  CpuEntity fromMap(Map<String, dynamic> map) {
    if (map.isEmpty) {
      return CpuEntity(usage: Percentage.fromRatio(0), cores: 1);
    }

    final ratioValue = coerceDouble(map['usageRatio'], fallback: double.nan);
    if (ratioValue.isNaN || ratioValue.isInfinite) {
      AppLog.warn('Discarding invalid CPU usage ratio: ${map['usageRatio']}');
      return CpuEntity(usage: Percentage.fromRatio(0), cores: 1);
    }

    final parsedCores = coerceInt(map['cores'], fallback: 0);
    final coresValue = parsedCores <= 0 ? 1 : parsedCores;

    return CpuEntity(
      usage: Percentage.fromRatio(ratioValue),
      cores: coresValue,
    );
  }
}
