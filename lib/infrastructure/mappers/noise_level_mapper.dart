import '../../core/utils/map_coercion.dart';
import '../../domain/entities/testers/noise_level_entity.dart';

class NoiseLevelMapper {
  const NoiseLevelMapper();

  /// Returns null for non-level frames (`error`, future kinds) so callers
  /// can keep showing the previous sample.
  NoiseLevelEntity? fromMap(Map<String, dynamic> map) {
    if (map['kind'] != 'level') return null;
    return NoiseLevelEntity(
      dbfs: coerceDouble(map['dbfs'], fallback: -120),
      splApprox: coerceDouble(map['spl'], fallback: 0),
      peakDbfs: coerceDouble(map['peakDbfs'], fallback: -120),
    );
  }
}
