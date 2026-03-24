import '../../domain/entities/battery_entity.dart';
import '../../domain/entities/cpu_entity.dart';
import '../../domain/value_objects/percentage.dart';
import '../../domain/entities/memory_entity.dart';
import '../../domain/repositories/system_repository.dart';
import '../datasources/android_system_datasource.dart';
import '../mappers/battery_mapper.dart';
import '../mappers/cpu_mapper.dart';
import '../mappers/memory_mapper.dart';

class SystemRepositoryImpl implements SystemRepository {
  SystemRepositoryImpl({
    required AndroidSystemDatasource datasource,
    required BatteryMapper batteryMapper,
    required MemoryMapper memoryMapper,
    required CpuMapper cpuMapper,
  }) : _datasource = datasource,
       _batteryMapper = batteryMapper,
       _memoryMapper = memoryMapper,
       _cpuMapper = cpuMapper;

  final AndroidSystemDatasource _datasource;
  final BatteryMapper _batteryMapper;
  final MemoryMapper _memoryMapper;
  final CpuMapper _cpuMapper;

  @override
  Stream<BatteryEntity> watchBattery() =>
      _datasource.batteryRaw().map(_batteryMapper.fromMap);

  @override
  Stream<MemoryEntity> watchMemory() =>
      _datasource.memoryRaw().map(_memoryMapper.fromMap);

  @override
  Stream<CpuEntity> watchCpu() async* {
    yield CpuEntity(usage: Percentage.fromRatio(0), cores: 1);

    await for (final event in _datasource.cpuRaw()) {
      yield _cpuMapper.fromMap(_cpuEventData(event));
    }
  }

  Map<String, dynamic> _cpuEventData(Map<String, dynamic> event) {
    final data = event['data'];
    if (event['ok'] == true && data is Map) {
      return data.cast<String, dynamic>();
    }
    return event;
  }
}
