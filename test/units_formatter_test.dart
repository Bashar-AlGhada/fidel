import 'package:flutter_test/flutter_test.dart';

import 'package:fidel/domain/units/units_formatter.dart';

void main() {
  test('formatElectricCurrent scales microamps to mA/A', () {
    final formatter = const UnitsFormatter();

    expect(formatter.formatElectricCurrent(microAmps: 500), '500 uA');
    expect(formatter.formatElectricCurrent(microAmps: 1500), '1.50 mA');
    expect(formatter.formatElectricCurrent(microAmps: 1234567), '1.23 A');
  });

  test('formatMillivolts scales to V above one volt', () {
    final formatter = const UnitsFormatter();

    expect(formatter.formatMillivolts(millivolts: 850), '850 mV');
    expect(formatter.formatMillivolts(millivolts: 3700), '3.70 V');
    expect(formatter.formatMillivolts(millivolts: -4200), '-4.20 V');
  });
}
