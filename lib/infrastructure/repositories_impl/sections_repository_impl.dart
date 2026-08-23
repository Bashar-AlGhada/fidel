import 'dart:async';

import 'package:rxdart/rxdart.dart';

import '../../core/logging/app_logger.dart';
import '../../domain/entities/info/info_availability.dart';
import '../../domain/entities/info/info_section_entity.dart';
import '../../domain/entities/sensors/sensor_entity.dart';
import '../../domain/repositories/sections_repository.dart';
import '../cache/local_cache_store.dart';
import '../datasources/android_system_datasource.dart';
import '../export/export_service.dart';
import '../mappers/info_section_mapper.dart';
import '../mappers/sensor_event_mapper.dart';
import 'sensor_feed_manager.dart';
import 'thermal_feed_manager.dart';

typedef _SectionHandler = ({
  Future<Map<String, dynamic>> Function() fetch,
  InfoSectionEntity Function(Map<String, dynamic>) map,
});

/// Facade for section metadata: fetch/cache/single-flight plus routing to
/// the two event-driven feed managers (thermal, sensors).
class SectionsRepositoryImpl implements SectionsRepository {
  SectionsRepositoryImpl({
    required AndroidSystemDatasource datasource,
    required InfoSectionMapper infoSectionMapper,
    required SensorEventMapper sensorEventMapper,
    required LocalCacheStore cacheStore,
  }) : _datasource = datasource,
       _infoSectionMapper = infoSectionMapper,
       _cacheStore = cacheStore {
    _thermalFeed = ThermalFeedManager(
      datasource: datasource,
      infoSectionMapper: infoSectionMapper,
      cacheStore: cacheStore,
      onEntity: (entity) => _metadataCache['thermal'] = entity,
    );
    _sensorFeed = SensorFeedManager(
      datasource: datasource,
      sensorEventMapper: sensorEventMapper,
      cacheStore: cacheStore,
      onData: _markSensorsSectionAvailable,
    );
  }

  final AndroidSystemDatasource _datasource;
  final InfoSectionMapper _infoSectionMapper;
  final LocalCacheStore _cacheStore;

  late final ThermalFeedManager _thermalFeed;
  late final SensorFeedManager _sensorFeed;

  /// Single source of truth mapping a section id to its snapshot endpoint
  /// and mapper. `device-build` composes two snapshots and stays special;
  /// `sensors`/`thermal` are event-driven rather than fetched.
  late final Map<String, _SectionHandler> _sectionHandlers = {
    'display': (
      fetch: _datasource.displaySnapshotResult,
      map: _infoSectionMapper.display,
    ),
    'memory-storage': (
      fetch: _datasource.memoryStorageSnapshotResult,
      map: _infoSectionMapper.memoryStorage,
    ),
    'battery': (
      fetch: _datasource.batterySnapshotResult,
      map: _infoSectionMapper.batteryDetailed,
    ),
    'cameras': (
      fetch: _datasource.camerasSnapshotResult,
      map: _infoSectionMapper.cameras,
    ),
    'cellular-sim': (
      fetch: _datasource.cellularSimSnapshotResult,
      map: _infoSectionMapper.cellularSim,
    ),
    'security-drm': (
      fetch: _datasource.securitySnapshotResult,
      map: _infoSectionMapper.securityDrm,
    ),
    'codecs': (
      fetch: _datasource.codecsSnapshotResult,
      map: _infoSectionMapper.codecs,
    ),
    'widi-miracast': (
      fetch: _datasource.widiMiracastSnapshotResult,
      map: _infoSectionMapper.widiMiracast,
    ),
  };

  static const Map<String, String> _sectionTitleKeys = {
    'device-build': 'section.deviceBuild',
    'display': 'section.display',
    'memory-storage': 'section.memoryStorage',
    'battery': 'section.batteryDetailed',
    'thermal': 'section.thermal',
    'cameras': 'section.cameras',
    'cellular-sim': 'section.cellularSim',
    'security-drm': 'section.securityDrm',
    'codecs': 'section.codecs',
    'widi-miracast': 'section.widiMiracast',
    'sensors': 'section.sensors',
  };

  final Map<String, InfoSectionEntity> _metadataCache = {};
  final Map<String, BehaviorSubject<InfoSectionEntity>> _sectionSubjects = {};
  final Map<String, Future<InfoSectionEntity>> _inFlightMetadata = {};
  final Set<String> _diskSeededSections = {};

  BehaviorSubject<InfoSectionEntity>? _sensorsSectionSubject;

  @override
  Future<InfoSectionEntity> getSectionMetadata(
    String sectionId, {
    bool forceRefresh = false,
  }) {
    final cached = _metadataCache[sectionId];
    if (!forceRefresh && cached != null) return Future.value(cached);

    // Single-flight: concurrent watchers (e.g. the /info grid) must not
    // stampede the platform channel for the same section.
    final inFlight = _inFlightMetadata[sectionId];
    if (inFlight != null) return inFlight;

    final future = _fetchSectionMetadata(sectionId, forceRefresh: forceRefresh);
    _inFlightMetadata[sectionId] = future;
    return future.whenComplete(() => _inFlightMetadata.remove(sectionId));
  }

  Future<InfoSectionEntity> _fetchSectionMetadata(
    String sectionId, {
    required bool forceRefresh,
  }) async {
    final cached = _metadataCache[sectionId];

    final titleKey = _titleKeyFor(sectionId);
    await _seedSectionFromDisk(sectionId);

    try {
      final handler = _sectionHandlers[sectionId];
      // Event-driven sections have no snapshot endpoint; their current
      // entity (live or disk-seeded) is already the freshest answer.
      final InfoSectionEntity? live = sectionId == 'thermal'
          ? _thermalFeed.current
          : sectionId == 'sensors'
          ? _metadataCache['sensors']
          : null;
      final section = switch (sectionId) {
        'device-build' => await _fetchDeviceBuild(),
        _ when handler != null => await _fetchSingle(
          sectionId: sectionId,
          titleKey: titleKey,
          fetch: handler.fetch,
          map: handler.map,
        ),
        _ =>
          live ??
              _infoSectionMapper.unavailable(id: sectionId, titleKey: titleKey),
      };

      if (section.availability == InfoAvailability.available) {
        _metadataCache[sectionId] = section;
        _sectionSubjects[sectionId]?.add(section);
      } else if (cached != null) {
        _sectionSubjects[sectionId]?.add(cached);
      } else {
        _sectionSubjects[sectionId]?.add(section);
      }

      return _metadataCache[sectionId] ?? cached ?? section;
    } catch (e, st) {
      AppLog.warn(
        'Section metadata fetch failed for "$sectionId"',
        error: e,
        stackTrace: st,
      );
      // Re-read the cache: disk seeding may have completed while the fetch
      // was in flight, and that fresh entry outranks the stale local.
      final freshest = _metadataCache[sectionId] ?? cached;
      if (freshest != null) return freshest;
      final fallback = _infoSectionMapper.unavailable(
        id: sectionId,
        titleKey: titleKey,
        availability: InfoAvailability.unavailable,
      );
      _sectionSubjects[sectionId]?.add(fallback);
      return fallback;
    }
  }

  @override
  Stream<InfoSectionEntity> watchSectionMetadata(String sectionId) {
    if (sectionId == 'thermal') return _watchThermal();
    if (sectionId == 'sensors') return _watchSensorsSection();

    final subject = _sectionSubjects.putIfAbsent(sectionId, () {
      final cached = _metadataCache[sectionId];
      return BehaviorSubject<InfoSectionEntity>.seeded(
        cached ??
            _infoSectionMapper.unavailable(
              id: sectionId,
              titleKey: _titleKeyFor(sectionId),
              availability: InfoAvailability.unavailable,
            ),
      );
    });

    unawaited(_seedSectionFromDisk(sectionId));
    unawaited(getSectionMetadata(sectionId));

    return subject.stream;
  }

  Stream<InfoSectionEntity> _watchThermal() {
    final seed =
        _metadataCache['thermal'] ??
        _infoSectionMapper.unavailable(
          id: 'thermal',
          titleKey: _titleKeyFor('thermal'),
          availability: InfoAvailability.unavailable,
        );

    return _thermalFeed.watch(seed);
  }

  /// Availability surface for the `/info` sensors tile. The tile does not
  /// drive the sensor feed; it flips to available as soon as any sensor
  /// data arrives (live or from disk).
  Stream<InfoSectionEntity> _watchSensorsSection() {
    _sensorsSectionSubject ??= BehaviorSubject<InfoSectionEntity>.seeded(
      _metadataCache['sensors'] ?? _unavailable('sensors'),
    );
    unawaited(_sensorFeed.seedFromDisk());
    return _sensorsSectionSubject!.stream;
  }

  void _markSensorsSectionAvailable() {
    if (_metadataCache['sensors']?.availability == InfoAvailability.available) {
      return;
    }
    final entity = _infoSectionMapper.unavailable(
      id: 'sensors',
      titleKey: _titleKeyFor('sensors'),
      availability: InfoAvailability.available,
    );
    _metadataCache['sensors'] = entity;
    _sensorsSectionSubject?.add(entity);
  }

  @override
  Stream<List<SensorEntity>> watchSensors({
    int maxSamples = 128,
    int samplingPeriodUs = 200000,
  }) {
    return _sensorFeed.watch(
      maxSamples: maxSamples,
      samplingPeriodUs: samplingPeriodUs,
    );
  }

  Future<InfoSectionEntity> _fetchDeviceBuild() async {
    final cached = _metadataCache['device-build'];

    final results = await Future.wait([
      _datasource.deviceSnapshotResult(),
      _datasource.buildSnapshotResult(),
    ]);

    final device = _resultData(results[0]);
    final build = _resultData(results[1]);
    if (device == null || build == null) {
      return cached ??
          _infoSectionMapper.unavailable(
            id: 'device-build',
            titleKey: _titleKeyFor('device-build'),
            availability: InfoAvailability.unavailable,
          );
    }

    // Same redaction the export path applies (fingerprints, serials…)
    // so nothing more sensitive lands in the plaintext cache.
    unawaited(
      _cacheStore.writeMap(
        'section_device-build',
        ExportService.sanitizeForExport(<String, dynamic>{
              'device': device,
              'build': build,
            })
            as Map<String, dynamic>,
      ),
    );
    return _infoSectionMapper.deviceAndBuild(device: device, build: build);
  }

  Future<InfoSectionEntity> _fetchSingle({
    required String sectionId,
    required String titleKey,
    required Future<Map<String, dynamic>> Function() fetch,
    required InfoSectionEntity Function(Map<String, dynamic>) map,
  }) async {
    final cached = _metadataCache[sectionId];
    final result = await fetch();
    final data = _resultData(result);
    if (data == null) {
      return cached ??
          _infoSectionMapper.unavailable(
            id: sectionId,
            titleKey: titleKey,
            availability: InfoAvailability.unavailable,
          );
    }
    unawaited(_cacheStore.writeMap('section_$sectionId', data));
    return map(data);
  }

  /// Unwraps a request/response envelope from the method channel.
  Map<String, dynamic>? _resultData(Map<String, dynamic> result) {
    if (result['ok'] != true) return null;
    final data = result['data'];
    if (data is! Map) return null;
    return data.cast<String, dynamic>();
  }

  String _titleKeyFor(String sectionId) {
    return _sectionTitleKeys[sectionId] ?? sectionId;
  }

  Future<void> _seedSectionFromDisk(String sectionId) async {
    // thermal/sensors seeding lives in their feed managers.
    if (_diskSeededSections.contains(sectionId) ||
        sectionId == 'thermal' ||
        sectionId == 'sensors') {
      return;
    }
    _diskSeededSections.add(sectionId);

    final cached = await _cacheStore.readMap('section_$sectionId');
    if (cached == null) return;

    final mapped = switch (sectionId) {
      'device-build' => () {
        final device = cached['device'];
        final build = cached['build'];
        if (device is! Map || build is! Map) {
          return _unavailable(sectionId);
        }
        return _infoSectionMapper.deviceAndBuild(
          device: device.cast<String, dynamic>(),
          build: build.cast<String, dynamic>(),
        );
      }(),
      _ => _sectionHandlers[sectionId]?.map(cached) ?? _unavailable(sectionId),
    };

    _metadataCache[sectionId] = mapped;
    _sectionSubjects[sectionId]?.add(mapped);
  }

  InfoSectionEntity _unavailable(String sectionId) {
    return _infoSectionMapper.unavailable(
      id: sectionId,
      titleKey: _titleKeyFor(sectionId),
      availability: InfoAvailability.unavailable,
    );
  }

  @override
  void dispose() {
    _thermalFeed.dispose();
    _sensorFeed.dispose();
    _sensorsSectionSubject?.close();
    _sensorsSectionSubject = null;
    for (final subject in _sectionSubjects.values) {
      subject.close();
    }
    _sectionSubjects.clear();
    _metadataCache.clear();
  }
}
