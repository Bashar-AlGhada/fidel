import '../entities/battery_entity.dart';
import '../entities/cpu_entity.dart';
import '../entities/memory_entity.dart';

abstract class SystemRepository {
  Stream<BatteryEntity> watchBattery();
  Stream<MemoryEntity> watchMemory();
  Stream<CpuEntity> watchCpu();
}
