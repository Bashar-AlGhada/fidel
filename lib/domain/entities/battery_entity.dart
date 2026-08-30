/// Live battery reading. Vitals are best-effort: several OEMs report no
/// current/voltage, so every field except [percent] may be null.
class BatteryEntity {
  const BatteryEntity({
    required this.percent,
    this.voltageV,
    this.currentMicroAmps,
    this.averageCurrentMicroAmps,
    this.temperatureC,
    this.capacityMah,
    this.chargeCounterUah,
    this.energyCounterNwh,
    this.charging,
    this.plugged,
    this.plugSource,
    this.status,
    this.health,
    this.watts,
    this.estimatedCurrentMicroAmps,
  });

  final int percent;
  final double? voltageV;

  /// Instantaneous pack current in microamps. Sign convention matches
  /// Android's CURRENT_NOW: negative while discharging, positive while
  /// charging.
  final double? currentMicroAmps;

  /// OS-reported average current in microamps (same sign convention as
  /// [currentMicroAmps]).
  final int? averageCurrentMicroAmps;

  final double? temperatureC;
  final double? capacityMah;

  /// Remaining charge in microamp-hours, when the fuel gauge exposes it.
  /// Input for the coulomb-counting estimate below.
  final int? chargeCounterUah;
  final int? energyCounterNwh;

  final bool? charging;
  final bool? plugged;

  /// Physical plug type: "ac", "usb", "wireless", "dock" or "battery".
  final String? plugSource;

  /// Charging state word: "charging", "full", "discharging",
  /// "not_charging" or "unknown".
  final String? status;

  /// Health word as reported by the battery manager ("good",
  /// "overheat", ...).
  final String? health;

  final double? watts;

  /// Coulomb-counted current derived from [chargeCounterUah] drift over
  /// a rolling window; null until enough samples accumulate. Same sign
  /// convention as [currentMicroAmps] (negative = discharging).
  final int? estimatedCurrentMicroAmps;

  /// Null-tolerant merge helper: every field falls back to the current
  /// value when the argument is null.
  BatteryEntity copyWith({
    int? percent,
    double? voltageV,
    double? currentMicroAmps,
    int? averageCurrentMicroAmps,
    double? temperatureC,
    double? capacityMah,
    int? chargeCounterUah,
    int? energyCounterNwh,
    bool? charging,
    bool? plugged,
    String? plugSource,
    String? status,
    String? health,
    double? watts,
    int? estimatedCurrentMicroAmps,
  }) {
    return BatteryEntity(
      percent: percent ?? this.percent,
      voltageV: voltageV ?? this.voltageV,
      currentMicroAmps: currentMicroAmps ?? this.currentMicroAmps,
      averageCurrentMicroAmps:
          averageCurrentMicroAmps ?? this.averageCurrentMicroAmps,
      temperatureC: temperatureC ?? this.temperatureC,
      capacityMah: capacityMah ?? this.capacityMah,
      chargeCounterUah: chargeCounterUah ?? this.chargeCounterUah,
      energyCounterNwh: energyCounterNwh ?? this.energyCounterNwh,
      charging: charging ?? this.charging,
      plugged: plugged ?? this.plugged,
      plugSource: plugSource ?? this.plugSource,
      status: status ?? this.status,
      health: health ?? this.health,
      watts: watts ?? this.watts,
      estimatedCurrentMicroAmps:
          estimatedCurrentMicroAmps ?? this.estimatedCurrentMicroAmps,
    );
  }
}
