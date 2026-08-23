import 'dart:async';

import 'package:rxdart/rxdart.dart';

import '../../core/logging/app_logger.dart';
import '../../domain/entities/info/info_section_entity.dart';
import '../cache/local_cache_store.dart';
import '../datasources/android_system_datasource.dart';
import '../mappers/info_section_mapper.dart';

/// Owns the live thermal feed: subject lifecycle, listener counting,
/// 2 s-throttled persistence and disk re-delivery.
///
/// [onEntity] lets the owning repository mirror every accepted entity into
/// its metadata cache.
class ThermalFeedManager {
  ThermalFeedManager({
    required AndroidSystemDatasource datasource,
    required InfoSectionMapper infoSectionMapper,
    required LocalCacheStore cacheStore,
    required void Function(InfoSectionEntity entity) onEntity,
  }) : _datasource = datasource,
       _infoSectionMapper = infoSectionMapper,
       _cacheStore = cacheStore,
       _onEntity = onEntity;

  final AndroidSystemDatasource _datasource;
  final InfoSectionMapper _infoSectionMapper;
  final LocalCacheStore _cacheStore;
  final void Function(InfoSectionEntity entity) _onEntity;

  BehaviorSubject<InfoSectionEntity>? _subject;
  StreamSubscription<Map<String, dynamic>>? _sub;
  int _listenerCount = 0;
  DateTime? _lastPersistAt;
  bool _diskSeeded = false;

  /// Latest accepted entity (live or disk), null until one arrives.
  InfoSectionEntity? get current => _current;

  /// Subscribes to the feed. [seed] is emitted immediately for new
  /// subjects; listening starts/persists the native subscription and a
  /// disk re-delivery is scheduled.
  Stream<InfoSectionEntity> watch(InfoSectionEntity seed) {
    _subject ??= BehaviorSubject<InfoSectionEntity>.seeded(seed);

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

  /// Reads `section_thermal` once and delivers it through the subject.
  Future<void> seedFromDisk() async {
    if (_diskSeeded) return;
    _diskSeeded = true;

    final cached = await _cacheStore.readMap('section_thermal');
    if (cached == null) return;

    final mapped = _infoSectionMapper.thermal(cached);
    _current = mapped;
    _onEntity(mapped);
    _subject?.add(mapped);
  }

  void ingest(Map<String, dynamic> data) {
    final mapped = _infoSectionMapper.thermal(data);
    _current = mapped;
    _onEntity(mapped);
    _subject?.add(mapped);

    final now = DateTime.now();
    final last = _lastPersistAt;
    if (last == null || now.difference(last) >= const Duration(seconds: 2)) {
      _lastPersistAt = now;
      unawaited(_cacheStore.writeMap('section_thermal', data));
    }
  }

  InfoSectionEntity? _current;

  void _ensureFeed() {
    if (_sub != null) return;

    _sub = _datasource.thermalEventsRaw().listen(
      (event) {
        // The bridge emits failures as stream errors, so any well-formed
        // map here is genuine data.
        final data = _eventData(event);
        if (data == null || data['kind'] != 'thermal') return;
        ingest(data);
      },
      onError: (Object e, StackTrace st) {
        AppLog.warn('Thermal feed error', error: e, stackTrace: st);
      },
    );
  }

  /// Normalizes a broadcast event. The bridge emits failures as stream
  /// errors, so any well-formed map here is genuine data.
  static Map<String, dynamic>? _eventData(Object? event) {
    if (event is Map<String, dynamic>) return event;
    if (event is Map) return event.cast<String, dynamic>();
    return null;
  }

  void _stopFeed() {
    unawaited(_sub?.cancel());
    _sub = null;
  }

  void dispose() {
    _stopFeed();
    _subject?.close();
    _subject = null;
  }
}
