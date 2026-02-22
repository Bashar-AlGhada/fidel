import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:fidel/application/providers/system_providers.dart';
import 'package:fidel/domain/entities/battery_entity.dart';
import 'package:fidel/domain/entities/cpu_entity.dart';
import 'package:fidel/domain/entities/memory_entity.dart';
import 'package:fidel/domain/repositories/system_repository.dart';
import 'package:fidel/domain/value_objects/percentage.dart';

class FakeSystemRepository implements SystemRepository {
  @override
  Stream<BatteryEntity> watchBattery() =>
      Stream.value(const BatteryEntity(percent: 42));

  @override
  Stream<MemoryEntity> watchMemory() =>
      Stream.value(const MemoryEntity(availBytes: 50, totalBytes: 100));

  @override
  Stream<CpuEntity> watchCpu() =>
      Stream.value(CpuEntity(usage: Percentage.fromRatio(0.5), cores: 8));
}

void main() {
  test('batteryStreamProvider emits battery data', () async {
    final container = ProviderContainer(
      overrides: [
        systemRepositoryProvider.overrideWithValue(FakeSystemRepository()),
      ],
    );
    addTearDown(container.dispose);

    final sub = container.listen(batteryStreamProvider, (prev, next) {});
    addTearDown(sub.close);

    final v = await container.read(batteryStreamProvider.future);
    expect(v.percent, 42);
  });
}
