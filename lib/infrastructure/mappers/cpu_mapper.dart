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

    // Fallback only when the key is absent entirely; a present-but-bogus
    // value still normalizes to 1 below.
    final parsedCores = coerceInt(map['cores'], fallback: 1);
    final cores = parsedCores <= 0 ? 1 : parsedCores;

    return CpuEntity(
      usage: Percentage.fromRatio(ratioValue),
      cores: cores,
      coreUsages: _coreUsages(map['coreUsages'], cores),
      coreFreqsMhz: _coreFreqsMhz(map['coreFreqsMhz'], cores),
    );
  }

  /// Coerces per-core usage ratios, clamps them to 0..1 and fits the
  /// result to [cores]: short lists pad with 0, long ones truncate.
  List<double> _coreUsages(Object? raw, int cores) {
    final source = raw is List ? raw : const [];
    final usages = List<double>.filled(cores, 0, growable: false);
    for (var i = 0; i < cores && i < source.length; i++) {
      var value = coerceDouble(source[i], fallback: 0);
      if (value.isNaN || value.isInfinite) value = 0;
      usages[i] = value.clamp(0.0, 1.0).toDouble();
    }
    return usages;
  }

  /// Per-core frequencies in MHz; null entries stay null and missing
  /// trailing slots pad with null.
  List<double?> _coreFreqsMhz(Object? raw, int cores) {
    final source = raw is List ? raw : const [];
    final freqs = List<double?>.filled(cores, null, growable: false);
    for (var i = 0; i < cores && i < source.length; i++) {
      final value = coerceDouble(source[i], fallback: double.nan);
      freqs[i] = value.isFinite ? value : null;
    }
    return freqs;
  }
}
