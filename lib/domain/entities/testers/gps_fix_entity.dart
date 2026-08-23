/// One GNSS fix. Satellite counts ride along from the status callback;
/// they may be null until the first status frame arrives.
class GpsFixEntity {
  const GpsFixEntity({
    required this.latitude,
    required this.longitude,
    this.altitudeM,
    this.speedMps,
    this.accuracyM,
    this.bearingDeg,
    this.satellitesUsed,
    this.satellitesTotal,
  });

  final double latitude;
  final double longitude;
  final double? altitudeM;
  final double? speedMps;
  final double? accuracyM;
  final double? bearingDeg;
  final int? satellitesUsed;
  final int? satellitesTotal;
}
