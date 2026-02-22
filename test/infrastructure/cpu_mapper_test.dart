import 'package:flutter_test/flutter_test.dart';
import 'package:fidel/infrastructure/mappers/cpu_mapper.dart';

void main() {
  test('CpuMapper tolerates missing keys', () {
    final m = CpuMapper();
    final e = m.fromMap(const {});
    expect(e.cores, 0);
    expect(e.usage.toWholePercent(), 0);
  });
}
