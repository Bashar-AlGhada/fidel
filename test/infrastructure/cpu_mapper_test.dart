import 'package:flutter_test/flutter_test.dart';
import 'package:fidel/infrastructure/mappers/cpu_mapper.dart';

void main() {
  test('CpuMapper tolerates missing keys', () {
    final m = CpuMapper();
    final e = m.fromMap(const {});
    expect(e.cores, 1);
    expect(e.usage.toWholePercent(), 0);
  });

  test('CpuMapper normalizes invalid core count', () {
    final m = CpuMapper();
    final e = m.fromMap(const {'usageRatio': 0.5, 'cores': 0});
    expect(e.cores, 1);
    expect(e.usage.toWholePercent(), 50);
  });
}
