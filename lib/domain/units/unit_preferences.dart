import 'unit_types.dart';

class UnitPreferences {
  const UnitPreferences({
    required this.temperature,
    required this.unitSystem,
    required this.dataSizeBase,
    required this.rateUnit,
  });

  final TemperatureUnit temperature;
  final UnitSystem unitSystem;
  final DataSizeBase dataSizeBase;
  final RateUnit rateUnit;

  static const defaults = UnitPreferences(
    temperature: TemperatureUnit.celsius,
    unitSystem: UnitSystem.metric,
    dataSizeBase: DataSizeBase.base2,
    rateUnit: RateUnit.bytesPerSecond,
  );

  UnitPreferences copyWith({
    TemperatureUnit? temperature,
    UnitSystem? unitSystem,
    DataSizeBase? dataSizeBase,
    RateUnit? rateUnit,
  }) {
    return UnitPreferences(
      temperature: temperature ?? this.temperature,
      unitSystem: unitSystem ?? this.unitSystem,
      dataSizeBase: dataSizeBase ?? this.dataSizeBase,
      rateUnit: rateUnit ?? this.rateUnit,
    );
  }
}
