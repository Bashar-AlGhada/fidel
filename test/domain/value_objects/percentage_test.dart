import 'package:flutter_test/flutter_test.dart';
import 'package:fidel/domain/value_objects/percentage.dart';

void main() {
  group('Percentage.fromRatio', () {
    test('clamps ratios above 1 down to 1', () {
      expect(Percentage.fromRatio(1.5).value, 1.0);
    });

    test('clamps negative ratios up to 0', () {
      expect(Percentage.fromRatio(-0.25).value, 0.0);
    });

    test('maps NaN to 0', () {
      expect(Percentage.fromRatio(double.nan).value, 0.0);
    });

    test('maps infinity to 1', () {
      expect(Percentage.fromRatio(double.infinity).value, 1.0);
      expect(Percentage.fromRatio(double.negativeInfinity).value, 0.0);
    });
  });

  group('Percentage.toWholePercent', () {
    test('rounds to the nearest whole percent', () {
      expect(Percentage.fromRatio(0.754).toWholePercent(), 75);
      expect(Percentage.fromRatio(0.756).toWholePercent(), 76);
      expect(Percentage.fromRatio(0.5).toWholePercent(), 50);
      expect(Percentage.fromRatio(1.0).toWholePercent(), 100);
      expect(Percentage.fromRatio(0.0).toWholePercent(), 0);
    });
  });
}
