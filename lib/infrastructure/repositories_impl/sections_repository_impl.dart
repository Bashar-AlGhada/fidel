import 'dart:async';

import 'package:rxdart/rxdart.dart';

import '../../domain/entities/info/info_availability.dart';
import '../../domain/entities/info/info_section_entity.dart';
import '../../domain/entities/sensors/bounded_sample_window.dart';
import '../../domain/entities/sensors/sensor_accuracy.dart';
import '../../domain/entities/sensors/sensor_capability_entity.dart';
import '../../domain/entities/sensors/sensor_entity.dart';
import '../../domain/entities/sensors/sensor_reading_entity.dart';
import '../../domain/repositories/sections_repository.dart';
import '../cache/local_cache_store.dart';
import '../datasources/android_system_datasource.dart';
import '../mappers/info_section_mapper.dart';
import '../mappers/sensor_event_mapper.dart';

class SectionsRepositoryImpl implements SectionsRepository {
  SectionsRepositoryImpl({
    required AndroidSystemDatasource datasource,
    required InfoSectionMapper infoSectionMapper,
    required SensorEventMapper sensorEventMapper,
    required LocalCacheStore cacheStore,
  }) : _datasource = datasource,
       _infoSectionMapper = infoSectionMapper,
       _sensorEventMapper = sensorEventMapper,
       _cacheStore = cacheStore;

  final AndroidSystemDatasource _datasource;
  final InfoSectionMapper _infoSectionMapper;
  final SensorEventMapper _sensorEventMapper;
  final LocalCacheStore _cacheStore;

  final Map<String, InfoSectionEntity> _metadataCache = {};
  final Map<String, BehaviorSubject<InfoSectionEntity>> _sectionSubjects = {};
  final Set<String> _diskSeededSections = {};

  StreamSubscription<Map<String, dynamic>>? _thermalSub;

  BehaviorSubject<List<SensorEntity>>? _sensorsSubject;
  StreamSubscription<Map<String, dynamic>>? _sensorsSub;
  int _sensorsListenerCount = 0;
  Timer? _sensorsEmitTimer;
  bool _sensorsEmitScheduled = false;
  bool _sensorsEmitPending = false;
  bool _diskSeededSensors = false;
  DateTime? _lastSensorsPersistAt;

  final Map<String, SensorCapabilityEntity> _sensorCapabilitiesByKey = {};
  final Map<String, BoundedSampleWindow<SensorReadingEntity>> _sensorSamplesByKey = {};
  List<String> _sortedSensorKeys = const [];
  bool _sortedSensorKeysDirty = true;
  int _sensorMaxSamples = 128;
  int _sensorSamplingPeriodUs = 200000;

  @override
  Future<InfoSectionEntity> getSectionMetadata(String sectionId, {bool forceRefresh = false}) async {
    final cached = _metadataCache[sectionId];
    if (!forceRefresh && cached != null) return cached;

    final titleKey = _titleKeyForSectionId(sectionId);
    await _seedSectionFromDisk(sectionId);

    try {
      final section = switch (sectionId) {
        'device-build' => await _fetchDeviceBuild(),
        'display' => await _fetchSingle(
          sectionId: sectionId,
          titleKey: titleKey,
          fetch: _datasource.displaySnapshotResult,
          map: _infoSectionMapper.display,
        ),
        'memory-storage' => await _fetchSingle(
          sectionId: sectionId,
          titleKey: titleKey,
          fetch: _datasource.memoryStorageSnapshotResult,
          map: _infoSectionMapper.memoryStorage,
        ),
        'battery' => await _fetchSingle(
          sectionId: sectionId,
          titleKey: titleKey,
          fetch: _datasource.batterySnapshotResult,
          map: _infoSectionMapper.batteryDetailed,
        ),
        'cameras' => await _fetchSingle(
          sectionId: sectionId,
          titleKey: titleKey,
          fetch: _datasource.camerasSnapshotResult,
          map: _infoSectionMapper.cameras,
        ),
        'cellular-sim' => await _fetchSingle(
          sectionId: sectionId,
          titleKey: titleKey,
          fetch: _datasource.cellularSimSnapshotResult,
          map: _infoSectionMapper.cellularSim,
        ),
        'security-drm' => await _fetchSingle(
          sectionId: sectionId,
          titleKey: titleKey,
          fetch: _datasource.securitySnapshotResult,
          map: _infoSectionMapper.securityDrm,
        ),
        'codecs' => await _fetchSingle(
          sectionId: sectionId,
          titleKey: titleKey,
          fetch: _datasource.codecsSnapshotResult,
          map: _infoSectionMapper.codecs,
        ),
        'widi-miracast' => await _fetchSingle(
          sectionId: sectionId,
          titleKey: titleKey,
          fetch: _datasource.widiMiracastSnapshotResult,
          map: _infoSectionMapper.widiMiracast,
        ),
        _ => _infoSectionMapper.unavailable(id: sectionId, titleKey: titleKey),
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
    } catch (_) {
      if (cached != null) return cached;
      final fallback = _infoSectionMapper.unavailable(id: sectionId, titleKey: titleKey, availability: InfoAvailability.unavailable);
      _sectionSubjects[sectionId]?.add(fallback);
      return fallback;
    }
  }

  @override
  Stream<InfoSectionEntity> watchSectionMetadata(String sectionId) {
    final subject = _sectionSubjects.putIfAbsent(sectionId, () {
      final cached = _metadataCache[sectionId];
      return BehaviorSubject<InfoSectionEntity>.seeded(
        cached ??
            _infoSectionMapper.unavailable(id: sectionId, titleKey: _titleKeyForSectionId(sectionId), availability: InfoAvailability.unavailable),
      );
    });

    unawaited(_seedSectionFromDisk(sectionId));
    if (sectionId == 'thermal') {
      _ensureThermalFeed(subject);
    } else {
      unawaited(getSectionMetadata(sectionId));
    }

    return subject.stream;
  }

  @override
  Stream<List<SensorEntity>> watchSensors({int maxSamples = 128, int samplingPeriodUs = 200000}) {
    final normalized = maxSamples.clamp(1, 512);
    _sensorMaxSamples = normalized;
    final normalizedSampling = samplingPeriodUs.clamp(10_000, 2_000_000);
    if (_sensorSamplingPeriodUs != normalizedSampling) {
      _sensorSamplingPeriodUs = normalizedSampling;
      unawaited(_sensorsSub?.cancel());
      _sensorsSub = null;
      if (_sensorsListenerCount > 0) {
        _ensureSensorsFeed();
      }
    }

    _sensorsSubject ??= BehaviorSubject<List<SensorEntity>>.seeded(_buildSensorsSnapshot());
    unawaited(_seedSensorsFromDisk());
    return _sensorsSubject!.stream
        .doOnListen(() {
          _sensorsListenerCount += 1;
          _ensureSensorsFeed();
        })
        .doOnCancel(() {
          _sensorsListenerCount -= 1;
          if (_sensorsListenerCount <= 0) {
            _sensorsListenerCount = 0;
            _stopSensorsFeed();
          }
        });
  }

  void _ensureThermalFeed(BehaviorSubject<InfoSectionEntity> subject) {
    if (_thermalSub != null) return;
    _thermalSub = _datasource.thermalEventsRaw().listen((event) {
      final data = _resultData(event);
      if (data == null) return;
      if (data['kind'] != 'thermal') return;

      final mapped = _infoSectionMapper.thermal(data);
      _metadataCache['thermal'] = mapped;
      subject.add(mapped);
      unawaited(_cacheStore.writeMap('section_thermal', data));
    });
  }

  void _ensureSensorsFeed() {
    if (_sensorsSub != null) return;

    _sensorsSub = _datasource.sensorEventsRaw(samplingPeriodUs: _sensorSamplingPeriodUs).listen((event) {
      final data = _resultData(event);
      if (data == null) return;

      final kind = data['kind'];
      if (kind is! String) return;

      switch (kind) {
        case 'capabilities':
          _handleSensorCapabilities(data);
          _scheduleEmitSensors();
          break;
        case 'reading':
          _handleSensorReading(data);
          _scheduleEmitSensors();
          break;
        case 'accuracy':
          break;
        default:
          break;
      }
    });
  }

  void _stopSensorsFeed() {
    unawaited(_sensorsSub?.cancel());
    _sensorsSub = null;
    _sensorsEmitTimer?.cancel();
    _sensorsEmitTimer = null;
    _sensorsEmitScheduled = false;
    _sensorsEmitPending = false;
  }

  void _handleSensorCapabilities(Map<String, dynamic> data) {
    final sensors = data['sensors'];
    if (sensors is! List) return;

    for (final raw in sensors) {
      if (raw is! Map) continue;
      final cap = _sensorEventMapper.capabilityFromMap(raw.cast<String, dynamic>());
      if (cap == null || cap.key.isEmpty) continue;
      _sensorCapabilitiesByKey[cap.key] = cap;
      _sensorSamplesByKey.putIfAbsent(cap.key, () => BoundedSampleWindow<SensorReadingEntity>(maxSamples: _sensorMaxSamples, samples: const []));
    }
    _sortedSensorKeysDirty = true;
    _persistSensorsIfNeeded(force: true);
  }

  void _handleSensorReading(Map<String, dynamic> data) {
    final key = _sensorEventMapper.keyFromMap(data);
    if (key == null) return;

    final reading = _sensorEventMapper.readingFromMap(data);
    if (reading == null) return;

    final wasKnownKey = _sensorSamplesByKey.containsKey(key);
    final existing = _sensorSamplesByKey[key];
    final next = (existing ?? BoundedSampleWindow<SensorReadingEntity>(maxSamples: _sensorMaxSamples, samples: const [])).push(reading);

    _sensorSamplesByKey[key] = next;

    final hadCapability = _sensorCapabilitiesByKey.containsKey(key);
    _sensorCapabilitiesByKey.putIfAbsent(
      key,
      () => SensorCapabilityEntity(
        key: key,
        name: '',
        vendor: '',
        type: (data['sensorType'] is num) ? (data['sensorType'] as num).toInt() : 0,
        maxRange: 0,
        resolution: 0,
        powerMilliAmp: 0,
        minDelay: Duration.zero,
      ),
    );
    if (!wasKnownKey || !hadCapability) {
      _sortedSensorKeysDirty = true;
    }
    _persistSensorsIfNeeded();
  }

  void _scheduleEmitSensors() {
    if (_sensorsSubject == null) return;
    if (_sensorsEmitScheduled) {
      _sensorsEmitPending = true;
      return;
    }

    _sensorsEmitScheduled = true;
    _sensorsSubject?.add(_buildSensorsSnapshot());

    _sensorsEmitTimer?.cancel();
    _sensorsEmitTimer = Timer(const Duration(milliseconds: 80), () {
      _sensorsEmitScheduled = false;
      if (!_sensorsEmitPending) return;
      _sensorsEmitPending = false;
      _scheduleEmitSensors();
    });
  }

  List<SensorEntity> _buildSensorsSnapshot() {
    if (_sortedSensorKeysDirty) {
      final keys = <String>{..._sensorCapabilitiesByKey.keys, ..._sensorSamplesByKey.keys}.toList(growable: false);

      keys.sort((a, b) {
        final ca = _sensorCapabilitiesByKey[a];
        final cb = _sensorCapabilitiesByKey[b];
        final ta = ca?.type ?? 0;
        final tb = cb?.type ?? 0;
        if (ta != tb) return ta.compareTo(tb);
        final na = ca?.name ?? '';
        final nb = cb?.name ?? '';
        final nameCmp = na.compareTo(nb);
        if (nameCmp != 0) return nameCmp;
        return a.compareTo(b);
      });

      _sortedSensorKeys = keys;
      _sortedSensorKeysDirty = false;
    }

    return _sortedSensorKeys
        .map((key) {
          final cap =
              _sensorCapabilitiesByKey[key] ??
              SensorCapabilityEntity(key: key, name: '', vendor: '', type: 0, maxRange: 0, resolution: 0, powerMilliAmp: 0, minDelay: Duration.zero);
          final samples = _sensorSamplesByKey[key] ?? BoundedSampleWindow<SensorReadingEntity>(maxSamples: _sensorMaxSamples, samples: const []);
          final aligned = samples.maxSamples == _sensorMaxSamples
              ? samples
              : BoundedSampleWindow<SensorReadingEntity>(maxSamples: _sensorMaxSamples, samples: samples.samples);
          return SensorEntity(capability: cap, samples: aligned);
        })
        .toList(growable: false);
  }

  Future<InfoSectionEntity> _fetchDeviceBuild() async {
    final cached = _metadataCache['device-build'];

    final results = await Future.wait([_datasource.deviceSnapshotResult(), _datasource.buildSnapshotResult()]);

    final device = _resultData(results[0]);
    final build = _resultData(results[1]);
    if (device == null || build == null) {
      return cached ??
          _infoSectionMapper.unavailable(
            id: 'device-build',
            titleKey: _titleKeyForSectionId('device-build'),
            availability: InfoAvailability.unavailable,
          );
    }

    unawaited(_cacheStore.writeMap('section_device-build', <String, dynamic>{'device': device, 'build': build}));
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
      return cached ?? _infoSectionMapper.unavailable(id: sectionId, titleKey: titleKey, availability: InfoAvailability.unavailable);
    }
    unawaited(_cacheStore.writeMap('section_$sectionId', data));
    return map(data);
  }

  Map<String, dynamic>? _resultData(Map<String, dynamic> result) {
    if (result['ok'] != true) return null;
    final data = result['data'];
    if (data is Map) return data.cast<String, dynamic>();
    return null;
  }

  String _titleKeyForSectionId(String sectionId) {
    return switch (sectionId) {
      'device-build' => 'section.deviceBuild',
      'display' => 'section.display',
      'memory-storage' => 'section.memoryStorage',
      'battery' => 'section.batteryDetailed',
      'thermal' => 'section.thermal',
      'cameras' => 'section.cameras',
      'cellular-sim' => 'section.cellularSim',
      'security-drm' => 'section.securityDrm',
      'codecs' => 'section.codecs',
      'widi-miracast' => 'section.widiMiracast',
      'sensors' => 'section.sensors',
      _ => sectionId,
    };
  }

  Future<void> _seedSectionFromDisk(String sectionId) async {
    if (_diskSeededSections.contains(sectionId)) return;
    _diskSeededSections.add(sectionId);

    final cached = await _cacheStore.readMap('section_$sectionId');
    if (cached == null) return;

    final mapped = switch (sectionId) {
      'device-build' => () {
        final device = cached['device'];
        final build = cached['build'];
        if (device is! Map || build is! Map) {
          return _infoSectionMapper.unavailable(
            id: sectionId,
            titleKey: _titleKeyForSectionId(sectionId),
            availability: InfoAvailability.unavailable,
          );
        }
        return _infoSectionMapper.deviceAndBuild(device: device.cast<String, dynamic>(), build: build.cast<String, dynamic>());
      }(),
      'display' => _infoSectionMapper.display(cached),
      'memory-storage' => _infoSectionMapper.memoryStorage(cached),
      'battery' => _infoSectionMapper.batteryDetailed(cached),
      'cameras' => _infoSectionMapper.cameras(cached),
      'cellular-sim' => _infoSectionMapper.cellularSim(cached),
      'security-drm' => _infoSectionMapper.securityDrm(cached),
      'codecs' => _infoSectionMapper.codecs(cached),
      'widi-miracast' => _infoSectionMapper.widiMiracast(cached),
      'thermal' => _infoSectionMapper.thermal(cached),
      _ => _infoSectionMapper.unavailable(id: sectionId, titleKey: _titleKeyForSectionId(sectionId), availability: InfoAvailability.unavailable),
    };

    _metadataCache[sectionId] = mapped;
    _sectionSubjects[sectionId]?.add(mapped);
  }

  Future<void> _seedSensorsFromDisk() async {
    if (_diskSeededSensors) return;
    _diskSeededSensors = true;

    final cached = await _cacheStore.readMap('sensors_cache');
    if (cached == null) return;

    final caps = cached['capabilities'];
    if (caps is List) {
      for (final raw in caps) {
        if (raw is! Map) continue;
        final map = raw.cast<String, dynamic>();
        final key = map['key'];
        if (key is! String || key.isEmpty) continue;
        _sensorCapabilitiesByKey[key] = SensorCapabilityEntity(
          key: key,
          name: (map['name'] as String?) ?? '',
          vendor: (map['vendor'] as String?) ?? '',
          type: (map['type'] is num) ? (map['type'] as num).toInt() : 0,
          maxRange: (map['maxRange'] is num) ? (map['maxRange'] as num).toDouble() : 0,
          resolution: (map['resolution'] is num) ? (map['resolution'] as num).toDouble() : 0,
          powerMilliAmp: (map['powerMilliAmp'] is num) ? (map['powerMilliAmp'] as num).toDouble() : 0,
          minDelay: Duration(microseconds: (map['minDelayUs'] is num) ? (map['minDelayUs'] as num).toInt() : 0),
        );
      }
    }

    final lastKnown = cached['lastKnown'];
    if (lastKnown is List) {
      for (final raw in lastKnown) {
        if (raw is! Map) continue;
        final map = raw.cast<String, dynamic>();
        final key = map['key'];
        if (key is! String || key.isEmpty) continue;
        final ts = map['timestampMs'];
        final values = map['values'];
        final accuracy = map['accuracy'];
        SensorAccuracy? parsedAccuracy;
        if (accuracy is String) {
          for (final a in SensorAccuracy.values) {
            if (a.name == accuracy) {
              parsedAccuracy = a;
              break;
            }
          }
        }
        final reading = SensorReadingEntity(
          timestamp: ts is num ? DateTime.fromMillisecondsSinceEpoch(ts.toInt()) : DateTime.now(),
          values: values is List ? values.whereType<num>().map((e) => e.toDouble()).toList(growable: false) : const [],
          accuracy: parsedAccuracy,
        );
        _sensorSamplesByKey[key] = BoundedSampleWindow<SensorReadingEntity>(maxSamples: _sensorMaxSamples, samples: [reading]);
      }
    }

    _sortedSensorKeysDirty = true;
    _sensorsSubject?.add(_buildSensorsSnapshot());
  }

  void _persistSensorsIfNeeded({bool force = false}) {
    final now = DateTime.now();
    if (!force) {
      final last = _lastSensorsPersistAt;
      if (last != null && now.difference(last) < const Duration(seconds: 2)) {
        return;
      }
    }
    _lastSensorsPersistAt = now;

    final caps = _sensorCapabilitiesByKey.values
        .map(
          (c) => <String, dynamic>{
            'key': c.key,
            'name': c.name,
            'vendor': c.vendor,
            'type': c.type,
            'maxRange': c.maxRange,
            'resolution': c.resolution,
            'powerMilliAmp': c.powerMilliAmp,
            'minDelayUs': c.minDelay.inMicroseconds,
          },
        )
        .toList(growable: false);

    final lastKnown = _sensorSamplesByKey.entries
        .map((e) {
          final last = e.value.samples.isEmpty ? null : e.value.samples.last;
          if (last == null) return null;
          return <String, dynamic>{
            'key': e.key,
            'timestampMs': last.timestamp.millisecondsSinceEpoch,
            'values': last.values,
            'accuracy': last.accuracy?.name,
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

    unawaited(_cacheStore.writeMap('sensors_cache', <String, dynamic>{'capabilities': caps, 'lastKnown': lastKnown}));
  }
}
