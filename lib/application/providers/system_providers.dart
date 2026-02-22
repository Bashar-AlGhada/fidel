import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../domain/entities/battery_entity.dart';
import '../../domain/entities/cpu_entity.dart';
import '../../domain/entities/info/info_section_entity.dart';
import '../../domain/entities/memory_entity.dart';
import '../../domain/entities/sensors/sensor_entity.dart';
import '../../domain/repositories/sections_repository.dart';
import '../../domain/repositories/system_repository.dart';
import '../../domain/usecases/get_section_metadata.dart';
import '../../domain/usecases/stream_battery.dart';
import '../../domain/usecases/stream_cpu.dart';
import '../../domain/usecases/stream_memory.dart';
import '../../domain/usecases/watch_section_metadata.dart';
import '../../domain/usecases/watch_sensors.dart';
import '../../infrastructure/cache/local_cache_store.dart';
import '../../infrastructure/datasources/android_system_datasource.dart';
import '../../infrastructure/mappers/battery_mapper.dart';
import '../../infrastructure/mappers/cpu_mapper.dart';
import '../../infrastructure/mappers/info_section_mapper.dart';
import '../../infrastructure/mappers/memory_mapper.dart';
import '../../infrastructure/mappers/sensor_event_mapper.dart';
import '../../infrastructure/repositories_impl/sections_repository_impl.dart';
import '../../infrastructure/repositories_impl/system_repository_impl.dart';

final androidSystemDatasourceProvider = Provider<AndroidSystemDatasource>(
  (ref) => AndroidSystemDatasource(),
);

final localCacheStoreProvider = Provider<LocalCacheStore>(
  (ref) => LocalCacheStore(),
);

final systemRepositoryProvider = Provider<SystemRepository>((ref) {
  return SystemRepositoryImpl(
    datasource: ref.read(androidSystemDatasourceProvider),
    batteryMapper: BatteryMapper(),
    memoryMapper: MemoryMapper(),
    cpuMapper: CpuMapper(),
  );
});

final sectionsRepositoryProvider = Provider<SectionsRepository>((ref) {
  return SectionsRepositoryImpl(
    datasource: ref.read(androidSystemDatasourceProvider),
    infoSectionMapper: InfoSectionMapper(),
    sensorEventMapper: SensorEventMapper(),
    cacheStore: ref.read(localCacheStoreProvider),
  );
});

final streamBatteryProvider = Provider<StreamBattery>(
  (ref) => StreamBattery(ref.read(systemRepositoryProvider)),
);
final streamMemoryProvider = Provider<StreamMemory>(
  (ref) => StreamMemory(ref.read(systemRepositoryProvider)),
);
final streamCpuProvider = Provider<StreamCpu>(
  (ref) => StreamCpu(ref.read(systemRepositoryProvider)),
);

final getSectionMetadataProvider = Provider<GetSectionMetadata>(
  (ref) => GetSectionMetadata(ref.read(sectionsRepositoryProvider)),
);
final watchSectionMetadataProvider = Provider<WatchSectionMetadata>(
  (ref) => WatchSectionMetadata(ref.read(sectionsRepositoryProvider)),
);
final watchSensorsProvider = Provider<WatchSensors>(
  (ref) => WatchSensors(ref.read(sectionsRepositoryProvider)),
);

final batteryStreamProvider = StreamProvider.autoDispose<BatteryEntity>(
  (ref) => ref.read(streamBatteryProvider)(),
);
final memoryStreamProvider = StreamProvider.autoDispose<MemoryEntity>(
  (ref) => ref.read(streamMemoryProvider)(),
);
final cpuStreamProvider = StreamProvider.autoDispose<CpuEntity>(
  (ref) => ref.read(streamCpuProvider)(),
);

final sectionMetadataStreamProvider = StreamProvider.autoDispose
    .family<InfoSectionEntity, String>(
      (ref, sectionId) => ref.read(watchSectionMetadataProvider)(sectionId),
    );

typedef SensorsStreamConfig = ({int samplingPeriodUs, int maxSamples});

final sensorsStreamProvider = StreamProvider.autoDispose
    .family<List<SensorEntity>, SensorsStreamConfig>(
      (ref, config) => ref.read(watchSensorsProvider)(
        maxSamples: config.maxSamples,
        samplingPeriodUs: config.samplingPeriodUs,
      ),
    );
