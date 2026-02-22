class SensorCapabilityEntity {
  const SensorCapabilityEntity({
    required this.key,
    required this.name,
    required this.vendor,
    required this.type,
    required this.maxRange,
    required this.resolution,
    required this.powerMilliAmp,
    required this.minDelay,
  });

  final String key;
  final String name;
  final String vendor;
  final int type;
  final double maxRange;
  final double resolution;
  final double powerMilliAmp;
  final Duration minDelay;
}
