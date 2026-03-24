import 'package:flutter_test/flutter_test.dart';

import 'package:fidel/infrastructure/units/units_formatter_impl.dart';

void main() {
  test('formatElectricCurrent scales microamps to mA/A', () {
    final formatter = UnitsFormatterImpl();

    expect(formatter.formatElectricCurrent(microAmps: 500), '500 uA');
    expect(formatter.formatElectricCurrent(microAmps: 1500), '1.50 mA');
    expect(formatter.formatElectricCurrent(microAmps: 1234567), '1.23 A');
  });
}
