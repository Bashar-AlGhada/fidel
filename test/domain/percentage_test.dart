import 'package:flutter_test/flutter_test.dart';
import 'package:fidel/domain/value_objects/percentage.dart';

void main() {
  test('Percentage clamps to [0,1]', () {
    final p1 = Percentage.fromRatio(-1);
    final p2 = Percentage.fromRatio(2);
    expect(p1.toWholePercent(), 0);
    expect(p2.toWholePercent(), 100);
  });
}
