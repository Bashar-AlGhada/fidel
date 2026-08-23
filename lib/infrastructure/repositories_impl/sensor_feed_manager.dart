import 'dart:async';

import 'package:rxdart/rxdart.dart';

import '../../core/logging/app_logger.dart';
import '../../domain/entities/sensors/bounded_sample_window.dart';
import '../../domain/entities/sensors/sensor_entity.dart';
import '../../domain/entities/sensors/sensor_capability_entity.dart';
import '../../domain/entities/sensors/sensor_reading_entity.dart';
import '../cache/local_cache_store.dart';
import '../datasources/android_system_datasource.dart';
import '../mappers/sensor_event_mapper.dart';

/// Owns the live sensor feed: native subscription lifecycle (including the
/// cancel-before-relisten resync), aggregation state, 80 ms emit
/// coalescing, disk seeding and 2 s-throttled persistence.
///
/// [onData] fires whenever real sensor data exists (live or disk) so the
/// owner can flip availability surfaces.
class SensorFeedManager {
  SensorFeedManager({
    required AndroidSystemDatasource datasource,
    required SensorEventMapper sensorEventMapper,
    required LocalCacheStore cacheStore,
    required void Function() onData,
  }) : _datasource = datasource,
       _sensorEventMapper = sensorEventMapper,
       _cacheStore = cacheStore,
       _onData = onData;

  final AndroidSystemDatasource _datasource;
  final SensorEventMapper _sensorEventMapper;
  final LocalCacheStore _cacheStore;
  final void Function() _onData;

  static const int _defaultMaxSamples = 128;
  static const int _defaultSamplingPeriodUs = 200000;

  BehaviorSubject<List<SensorEntity>>? _subject;
  StreamSubscription<Map<String, dynamic>>? _sub;
  int _listenerCount = 0;
  Timer? _emitTimer;
  bool _emitScheduled = false;
  bool _emitPending = false;
  bool _diskSeeded = false;
  DateTime? _lastPersistAt;

  final Map<String, SensorCapabilityEntity> _capabilitiesByKey = {};
  final Map<String, BoundedSampleWindow<SensorReadingEntity>> _samplesByKey =
      {};
  List<String> _sortedKeys = const [];
  bool _sortedKeysDirty = true;
  int _maxSamples = _defaultMaxSamples;
  int _samplingPeriodUs = _defaultSamplingPeriodUs;

  /// Subscribes to the aggregated snapshot stream, applying the new
  /// sampling configuration (resubscribing natively when the period
  /// changes) and scheduling a disk seed.
  Stream<List<SensorEntity>> watch({
    required int maxSamples,
    required int samplingPeriodUs,
  }) {
    final normalized = maxSamples.clamp(1, 512);
    _maxSamples = normalized;
    final normalizedSampling = samplingPeriodUs.clamp(10_000, 2_000_000);
    if (_samplingPeriodUs != normalizedSampling) {
      _samplingPeriodUs = normalizedSampling;
      final stale = _sub;
      _sub = null;
      // Cancel BEFORE re-listening: the platform registers one handler per
      // channel, so an overlapping cancel from the stale subscription can
      // unregister the fresh stream's handler and silently kill the feed.
      // The brief gap is far preferable to a dead sensor stream.
      unawaited(_resyncFeed(stale));
    }

    _subject ??= BehaviorSubject<List<SensorEntity>>.seeded(_buildSnapshot());
    unawaited(seedFromDisk());
    return _subject!.stream
        .doOnListen(() {
          _listenerCount += 1;
          _ensureFeed();
        })
        .doOnCancel(() {
          _listenerCount -= 1;
          if (_listenerCount <= 0) {
            _listenerCount = 0;
            _stopFeed();
          }
        });
  }

  /// Reads `sensors_cache` once. Live windows always win over stale disk
  /// rows; discovering capabilities marks the feed as having data.
  Future<void> seedFromDisk() async {
    if (_diskSeeded) return;
    _diskSeeded = true;

    final cached = await _cacheStore.readMap('sensors_cache');
    if (cached == null) return;

    final caps = cached['capabilities'];
    if (caps is List && caps.isNotEmpty) {
      _onData();
      for (final raw in caps) {
        if (raw is! Map) continue;
        final cap = _sensorEventMapper.capabilityFromMap(
          raw.cast<String, dynamic>(),
        );
        if (cap.key.isEmpty) continue;
        // Live data wins over stale disk rows.
        _capabilitiesByKey.putIfAbsent(cap.key, () => cap);
      }
    }

    final lastKnown = cached['lastKnown'];
    if (lastKnown is List) {
      for (final raw in lastKnown) {
        if (raw is! Map) continue;
        final map = raw.cast<String, dynamic>();
        final key = _sensorEventMapper.keyFromMap(map);
        if (key == null) continue;
        // Never clobber sample windows that accumulated live while the
        // disk read was in flight.
        if (_samplesByKey.containsKey(key)) continue;
        final reading = _sensorEventMapper.readingFromMap(map);
        _samplesByKey[key] = BoundedSampleWindow<SensorReadingEntity>(
          maxSamples: _maxSamples,
          samples: [reading],
        );
      }
    }

    _sortedKeysDirty = true;
    _subject?.add(_buildSnapshot());
  }

  void dispose() {
    _stopFeed();
    _subject?.close();
    _subject = null;
    _capabilitiesByKey.clear();
    _samplesByKey.clear();
  }

  void _ensureFeed() {
    if (_sub != null) return;
    _sub = _datasource
        .sensorEventsRaw(samplingPeriodUs: _samplingPeriodUs)
        .listen(
          (event) {
            final data = _eventData(event);
            if (data == null) return;

            switch (data['kind']) {
              case 'capabilities':
                _handleCapabilities(data);
                _scheduleEmit();
              case 'reading':
                _handleReading(data);
                _scheduleEmit();
            }
          },
          onError: (Object e, StackTrace st) {
            AppLog.warn('Sensor feed error', error: e, stackTrace: st);
          },
        );
  }

  void _stopFeed() {
    unawaited(_sub?.cancel());
    _sub = null;
    _emitTimer?.cancel();
    _emitTimer = null;
    _emitScheduled = false;
    _emitPending = false;
  }

  Future<void> _resyncFeed(
    StreamSubscription<Map<String, dynamic>>? stale,
  ) async {
    try {
      await stale?.cancel();
    } catch (e, st) {
      AppLog.warn(
        'Stale sensor subscription cancel failed',
        error: e,
        stackTrace: st,
      );
    }
    if (_listenerCount > 0 && _sub == null) {
      _ensureFeed();
    }
  }

  void _handleCapabilities(Map<String, dynamic> data) {
    final sensors = data['sensors'];
    if (sensors is! List) return;

    for (final raw in sensors) {
      if (raw is! Map) continue;
      final cap = _sensorEventMapper.capabilityFromMap(
        raw.cast<String, dynamic>(),
      );
      if (cap.key.isEmpty) continue;
      _capabilitiesByKey[cap.key] = cap;
      _samplesByKey.putIfAbsent(
        cap.key,
        () => BoundedSampleWindow<SensorReadingEntity>(
          maxSamples: _maxSamples,
          samples: const [],
        ),
      );
    }
    _sortedKeysDirty = true;
    _persistIfNeeded(force: true);
  }

  void _handleReading(Map<String, dynamic> data) {
    final key = _sensorEventMapper.keyFromMap(data);
    if (key == null) return;

    final reading = _sensorEventMapper.readingFromMap(data);

    final wasKnownKey = _samplesByKey.containsKey(key);
    final existing = _samplesByKey[key];
    final next =
        (existing ??
                BoundedSampleWindow<SensorReadingEntity>(
                  maxSamples: _maxSamples,
                  samples: const [],
                ))
            .push(reading);

    _samplesByKey[key] = next;

    final hadCapability = _capabilitiesByKey.containsKey(key);
    _capabilitiesByKey.putIfAbsent(
      key,
      () => SensorCapabilityEntity(
        key: key,
        name: '',
        vendor: '',
        type: (data['sensorType'] is num)
            ? (data['sensorType'] as num).toInt()
            : 0,
        maxRange: 0,
        resolution: 0,
        powerMilliAmp: 0,
        minDelay: Duration.zero,
      ),
    );
    if (!wasKnownKey || !hadCapability) {
      _sortedKeysDirty = true;
    }
    _persistIfNeeded();
  }

  void _scheduleEmit() {
    if (_subject == null) return;
    _onData();
    if (_emitScheduled) {
      _emitPending = true;
      return;
    }

    _emitScheduled = true;
    _subject?.add(_buildSnapshot());

    _emitTimer?.cancel();
    _emitTimer = Timer(const Duration(milliseconds: 80), () {
      _emitScheduled = false;
      if (!_emitPending) return;
      _emitPending = false;
      _scheduleEmit();
    });
  }

  List<SensorEntity> _buildSnapshot() {
    if (_sortedKeysDirty) {
      final keys = <String>{
        ..._capabilitiesByKey.keys,
        ..._samplesByKey.keys,
      }.toList(growable: false);

      keys.sort((a, b) {
        final ca = _capabilitiesByKey[a];
        final cb = _capabilitiesByKey[b];
        final ta = ca?.type ?? 0;
        final tb = cb?.type ?? 0;
        if (ta != tb) return ta.compareTo(tb);
        final na = ca?.name ?? '';
        final nb = cb?.name ?? '';
        final nameCmp = na.compareTo(nb);
        if (nameCmp != 0) return nameCmp;
        return a.compareTo(b);
      });

      _sortedKeys = keys;
      _sortedKeysDirty = false;
    }

    return _sortedKeys
        .map((key) {
          final cap =
              _capabilitiesByKey[key] ??
              SensorCapabilityEntity(
                key: key,
                name: '',
                vendor: '',
                type: 0,
                maxRange: 0,
                resolution: 0,
                powerMilliAmp: 0,
                minDelay: Duration.zero,
              );
          final samples =
              _samplesByKey[key] ??
              BoundedSampleWindow<SensorReadingEntity>(
                maxSamples: _maxSamples,
                samples: const [],
              );
          final BoundedSampleWindow<SensorReadingEntity> aligned;
          if (samples.maxSamples == _maxSamples) {
            aligned = samples;
          } else {
            // Persist the re-capped window so growing the limit actually
            // lets future pushes accumulate past the old cap.
            aligned = BoundedSampleWindow<SensorReadingEntity>(
              maxSamples: _maxSamples,
              samples: samples.samples,
            );
            _samplesByKey[key] = aligned;
          }
          return SensorEntity(capability: cap, samples: aligned);
        })
        .toList(growable: false);
  }

  void _persistIfNeeded({bool force = false}) {
    final now = DateTime.now();
    if (!force) {
      final last = _lastPersistAt;
      if (last != null && now.difference(last) < const Duration(seconds: 2)) {
        return;
      }
    }
    _lastPersistAt = now;

    final caps = _capabilitiesByKey.values
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

    final lastKnown = _samplesByKey.entries
        .map((e) {
          final last = e.value.samples.isEmpty ? null : e.value.samples.last;
          if (last == null) return null;
          return <String, dynamic>{
            'key': e.key,
            'timestampMs': last.timestamp.millisecondsSinceEpoch,
            // JSON cannot encode NaN/Infinity; null round-trips back to
            // NaN through the mapper while keeping channel positions.
            'values': [for (final v in last.values) v.isFinite ? v : null],
            'accuracy': last.accuracy?.name,
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

    unawaited(
      _cacheStore.writeMap('sensors_cache', <String, dynamic>{
        'capabilities': caps,
        'lastKnown': lastKnown,
      }),
    );
  }

  /// Normalizes a broadcast event. The bridge emits failures as stream
  /// errors, so any well-formed map here is genuine data.
  static Map<String, dynamic>? _eventData(Object? event) {
    if (event is Map<String, dynamic>) return event;
    if (event is Map) return event.cast<String, dynamic>();
    return null;
  }
}
