import 'package:flutter_test/flutter_test.dart';

import 'package:fidel/domain/units/measurement_formatter.dart';

void main() {
  test('returns em dash for null, NaN and infinite values', () {
    expect(formatMeasurement(null), '—');
    expect(formatMeasurement(double.nan), '—');
    expect(formatMeasurement(double.infinity), '—');
    expect(formatMeasurement(double.negativeInfinity), '—');
  });

  test('formats zero without scientific notation', () {
    expect(formatMeasurement(0), '0');
    expect(formatMeasurement(0.0), '0');
  });

  test('limits output to significant digits and strips trailing zeros', () {
    expect(formatMeasurement(9.81), '9.81');
    expect(formatMeasurement(0.009999999776482582), '0.01');
    expect(formatMeasurement(22.333333), '22.33');
  });

  test('rounds values needing fewer significant digits than integer digits',
      () {
    expect(formatMeasurement(-12345), '-12350');
    expect(formatMeasurement(999999), '1000000');
  });

  test('uses superscript scientific form below 1e-4', () {
    expect(formatMeasurement(2.1e-9), '2.1×10⁻⁹');
    expect(formatMeasurement(-3.14e-7, maxSignificantDigits: 3),
        '-3.14×10⁻⁷');
  });

  test('uses superscript scientific form at or above 1e6', () {
    expect(formatMeasurement(12345678), '1.235×10⁷');
    expect(formatMeasurement(1e6), '1×10⁶');
  });

  test('appends unit with a thin space when provided', () {
    expect(formatMeasurement(42.5, unit: '°C'), '42.5\u2009°C');
    expect(formatMeasurement(1013.25, unit: 'hPa'), '1013\u2009hPa');
    expect(formatMeasurement(42.5, unit: ''), '42.5');
  });

  test('formatList joins formatted measurements with commas', () {
    expect(formatList([0.1, 22.333333, -4]), '0.1, 22.33, -4');
    expect(formatList(<double>[]), '');
  });
}
