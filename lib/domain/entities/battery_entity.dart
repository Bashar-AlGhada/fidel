/// Live battery reading. Vitals are best-effort: several OEMs report no
/// current/voltage, so every field except [percent] may be null.
class BatteryEntity {
  const BatteryEntity({
    required this.percent,
    this.voltageV,
    this.currentMicroAmps,
    this.temperatureC,
    this.capacityMah,
    this.charging,
    this.plugged,
    this.watts,
  });

  final int percent;
  final double? voltageV;
  final double? currentMicroAmps;
  final double? temperatureC;
  final double? capacityMah;
  final bool? charging;
  final bool? plugged;
  final double? watts;
}
