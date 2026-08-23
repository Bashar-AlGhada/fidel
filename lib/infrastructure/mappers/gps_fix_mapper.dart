import '../../domain/entities/testers/gps_fix_entity.dart';
import '../../core/utils/map_coercion.dart';

/// Maps native GNSS frames onto [GpsFixEntity].
///
/// Satellite counts travel on separate `satellites` frames; the repository
/// threads them in via [satellitesUsed]/[satellitesTotal] so fixes carry
/// fresh counts without ordering assumptions.
class GpsFixMapper {
  const GpsFixMapper();

  /// Returns null for non-fix frames (`satellites`, `error`).
  GpsFixEntity? fromMap(
    Map<String, dynamic> map, {
    int? satellitesUsed,
    int? satellitesTotal,
  }) {
    if (map['kind'] != 'fix') return null;
    // Satellite counts use -1 as the 'absent' sentinel because native
    // omits them on fix frames; -1 can never be a real count.

    double? finite(Object? raw) {
      final v = coerceDouble(raw, fallback: double.nan);
      return v.isFinite ? v : null;
    }

    return GpsFixEntity(
      latitude: coerceDouble(map['latitude'], fallback: 0),
      longitude: coerceDouble(map['longitude'], fallback: 0),
      altitudeM: finite(map['altitudeM']),
      speedMps: finite(map['speedMps']),
      accuracyM: finite(map['accuracyM']),
      bearingDeg: finite(map['bearingDeg']),
      satellitesUsed: coerceInt(map['satellitesUsed'], fallback: -1) >= 0
          ? coerceInt(map['satellitesUsed'], fallback: -1)
          : satellitesUsed,
      satellitesTotal: coerceInt(map['satellitesTotal'], fallback: -1) >= 0
          ? coerceInt(map['satellitesTotal'], fallback: -1)
          : satellitesTotal,
    );
  }
}
