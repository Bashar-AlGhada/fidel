import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../domain/entities/battery_entity.dart';
import '../../domain/entities/cpu_entity.dart';
import '../../domain/entities/info/info_section_entity.dart';
import '../../domain/entities/memory_entity.dart';
import '../../domain/entities/sensors/sensor_entity.dart';
import '../../domain/repositories/sections_repository.dart';
import '../../domain/repositories/system_repository.dart';
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
    batteryMapper: const BatteryMapper(),
    memoryMapper: MemoryMapper(),
    cpuMapper: CpuMapper(),
  );
});

final sectionsRepositoryProvider = Provider<SectionsRepository>((ref) {
  final repository = SectionsRepositoryImpl(
    datasource: ref.read(androidSystemDatasourceProvider),
    infoSectionMapper: InfoSectionMapper(),
    sensorEventMapper: SensorEventMapper(),
    cacheStore: ref.read(localCacheStoreProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

/// Keep-alive: 1 Hz platform feeds are cheap and seeding them app-long
/// removes spinner flashes on every dashboard↔monitor round-trip.
final batteryStreamProvider = StreamProvider<BatteryEntity>(
  (ref) => ref.watch(systemRepositoryProvider).watchBattery(),
);

final memoryStreamProvider = StreamProvider<MemoryEntity>(
  (ref) => ref.watch(systemRepositoryProvider).watchMemory(),
);

final cpuStreamProvider = StreamProvider<CpuEntity>(
  (ref) => ref.watch(systemRepositoryProvider).watchCpu(),
);

final getSectionMetadataProvider =
    Provider<Future<InfoSectionEntity> Function(String, {bool forceRefresh})>((
      ref,
    ) {
      final repository = ref.read(sectionsRepositoryProvider);
      return (sectionId, {forceRefresh = false}) =>
          repository.getSectionMetadata(sectionId, forceRefresh: forceRefresh);
    });

final sectionMetadataStreamProvider = StreamProvider.autoDispose
    .family<InfoSectionEntity, String>(
      (ref, sectionId) =>
          ref.watch(sectionsRepositoryProvider).watchSectionMetadata(sectionId),
    );

typedef SensorsStreamConfig = ({int samplingPeriodUs, int maxSamples});

/// Single source of truth for sensor sampling. The list page, detail page
/// and compass all consume this, so a change on one surface survives
/// navigation instead of being silently reverted by sibling defaults.
class SensorsConfigController extends Notifier<SensorsStreamConfig> {
  @override
  SensorsStreamConfig build() => defaultSensorStreamConfig;

  void update({int? samplingPeriodUs, int? maxSamples}) {
    state = (
      samplingPeriodUs: samplingPeriodUs ?? state.samplingPeriodUs,
      maxSamples: maxSamples ?? state.maxSamples,
    );
  }
}

final sensorsConfigProvider =
    NotifierProvider<SensorsConfigController, SensorsStreamConfig>(
      SensorsConfigController.new,
    );

/// Defaults shared by every sensors-stream consumer (compass, detail).
const SensorsStreamConfig defaultSensorStreamConfig = (
  samplingPeriodUs: 200000,
  maxSamples: 128,
);

final sensorsStreamProvider = StreamProvider.autoDispose
    .family<List<SensorEntity>, SensorsStreamConfig>(
      (ref, config) => ref
          .watch(sectionsRepositoryProvider)
          .watchSensors(
            maxSamples: config.maxSamples,
            samplingPeriodUs: config.samplingPeriodUs,
          ),
    );
