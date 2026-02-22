import 'package:flutter_test/flutter_test.dart';
import 'package:fidel/domain/units/unit_preferences.dart';
import 'package:fidel/domain/units/unit_types.dart';

void main() {
  test('UnitPreferences.defaults is stable and copyWith overrides fields', () {
    const prefs = UnitPreferences.defaults;
    expect(prefs.temperature, TemperatureUnit.celsius);
    expect(prefs.dataSizeBase, DataSizeBase.base2);

    final updated = prefs.copyWith(
      temperature: TemperatureUnit.fahrenheit,
      dataSizeBase: DataSizeBase.base10,
    );
    expect(updated.temperature, TemperatureUnit.fahrenheit);
    expect(updated.dataSizeBase, DataSizeBase.base10);
    expect(updated.rateUnit, prefs.rateUnit);
    expect(updated.unitSystem, prefs.unitSystem);
  });
}
