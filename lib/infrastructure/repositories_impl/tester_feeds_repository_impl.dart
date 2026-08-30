import 'dart:async';

import 'package:flutter/services.dart' show PlatformException;
import 'package:rxdart/rxdart.dart';

import '../../core/logging/app_logger.dart';
import '../../domain/entities/testers/gps_fix_entity.dart';
import '../../domain/entities/testers/network_status_entity.dart';
import '../../domain/entities/testers/noise_level_entity.dart';
import '../../domain/repositories/tester_feeds_repository.dart';
import '../datasources/android_system_datasource.dart';
import '../mappers/gps_fix_mapper.dart';
import '../mappers/network_status_mapper.dart';
import '../mappers/noise_level_mapper.dart';

class TesterFeedsRepositoryImpl implements TesterFeedsRepository {
  TesterFeedsRepositoryImpl({
    required AndroidSystemDatasource datasource,
    required NetworkStatusMapper networkStatusMapper,
    required NoiseLevelMapper noiseLevelMapper,
    required GpsFixMapper gpsFixMapper,
  }) : _datasource = datasource,
       _networkStatusMapper = networkStatusMapper,
       _noiseLevelMapper = noiseLevelMapper,
       _gpsFixMapper = gpsFixMapper;

  final AndroidSystemDatasource _datasource;
  final NetworkStatusMapper _networkStatusMapper;
  final NoiseLevelMapper _noiseLevelMapper;
  final GpsFixMapper _gpsFixMapper;

  /// Cold-start guard for the network feed: a source that never emits
  /// surfaces as a `feed_timeout` error instead of endless Loading. The
  /// sink-based callback keeps the stream open and resets its countdown
  /// on every event, so late frames still flow after a timeout fired.
  static const Duration _feedTimeout = Duration(seconds: 5);

  BehaviorSubject<NoiseLevelEntity>? _noiseSubject;
  StreamSubscription<Map<String, dynamic>>? _noiseSub;

  BehaviorSubject<NetworkStatusEntity>? _networkSubject;
  StreamSubscription<Map<String, dynamic>>? _networkSub;
  NetworkStatusEntity? _lastNetwork;

  BehaviorSubject<GpsFixEntity>? _gpsSubject;
  StreamSubscription<Map<String, dynamic>>? _gpsSub;
  int? _lastSatellitesUsed;
  int? _lastSatellitesTotal;

  @override
  Stream<NoiseLevelEntity> watchNoiseLevel() {
    _noiseSubject ??= BehaviorSubject<NoiseLevelEntity>();
    _ensureNoiseFeed();
    return _noiseSubject!.stream.doOnCancel(_stopNoiseFeed);
  }

  @override
  Stream<NetworkStatusEntity> watchNetworkStatus() {
    _networkSubject ??= BehaviorSubject<NetworkStatusEntity>();
    _ensureNetworkFeed();
    return _networkSubject!.stream.doOnCancel(_stopNetworkFeed);
  }

  @override
  Stream<GpsFixEntity> watchGpsFix() {
    _gpsSubject ??= BehaviorSubject<GpsFixEntity>();
    _ensureGpsFeed();
    return _gpsSubject!.stream.doOnCancel(_stopGpsFeed);
  }

  void _ensureNoiseFeed() {
    if (_noiseSub != null) return;
    _noiseSub = _datasource.noiseEventsRaw().listen(
      (event) {
        if (event['kind'] == 'error') {
          AppLog.warn(
            'Noise feed failed: ${event['code']} ${event['message']}',
          );
          _noiseSubject?.addError(
            StateError('${event['code']}: ${event['message']}'),
          );
          return;
        }
        final level = _noiseLevelMapper.fromMap(event);
        if (level == null) return;
        _noiseSubject?.add(level);
      },
      onError: (Object e, StackTrace st) {
        AppLog.warn('Noise feed error', error: e, stackTrace: st);
        _noiseSubject?.addError(e);
      },
    );
  }

  void _stopNoiseFeed() {
    unawaited(_noiseSub?.cancel());
    _noiseSub = null;
  }

  void _ensureNetworkFeed() {
    if (_networkSub != null) return;
    _networkSub = _datasource
        .networkEventsRaw()
        .timeout(
          _feedTimeout,
          onTimeout: (EventSink<Map<String, dynamic>> sink) => sink.addError(
            PlatformException(
              code: 'feed_timeout',
              message: 'Native feed did not produce data.',
            ),
          ),
        )
        .listen(
          (event) {
            // Native failure frames are intercepted before mapping so they
            // surface as stream errors, never as entity updates.
            if (event['kind'] == 'error') {
              AppLog.warn(
                'Network feed failed: ${event['code']} ${event['message']}',
              );
              final code = event['code'];
              _networkSubject?.addError(
                PlatformException(
                  code: code is String && code.isNotEmpty
                      ? code
                      : 'network_error',
                  message: event['message']?.toString(),
                ),
              );
              return;
            }
            final next = _networkStatusMapper.fromMap(
              event,
              previous: _lastNetwork,
            );
            _lastNetwork = next;
            _networkSubject?.add(next);
          },
          onError: (Object e, StackTrace st) {
            AppLog.warn('Network feed error', error: e, stackTrace: st);
            _networkSubject?.addError(e);
          },
        );
  }

  void _stopNetworkFeed() {
    unawaited(_networkSub?.cancel());
    _networkSub = null;
  }

  void _ensureGpsFeed() {
    if (_gpsSub != null) return;
    _gpsSub = _datasource.gpsEventsRaw().listen(
      (event) {
        final kind = event['kind'];
        if (kind == 'satellites') {
          _lastSatellitesUsed = event['used'] is int
              ? event['used'] as int
              : _lastSatellitesUsed;
          _lastSatellitesTotal = event['total'] is int
              ? event['total'] as int
              : _lastSatellitesTotal;
          return;
        }
        if (kind == 'error') {
          AppLog.warn('GNSS feed failed: ${event['code']} ${event['message']}');
          _gpsSubject?.addError(
            StateError('${event['code']}: ${event['message']}'),
          );
          return;
        }
        if (kind != 'fix') return;

        final fix = _gpsFixMapper.fromMap(
          event,
          satellitesUsed: _lastSatellitesUsed,
          satellitesTotal: _lastSatellitesTotal,
        );
        if (fix != null) _gpsSubject?.add(fix);
      },
      onError: (Object e, StackTrace st) {
        AppLog.warn('GNSS feed error', error: e, stackTrace: st);
      },
    );
  }

  void _stopGpsFeed() {
    unawaited(_gpsSub?.cancel());
    _gpsSub = null;
  }

  @override
  void dispose() {
    _stopNoiseFeed();
    _stopNetworkFeed();
    _stopGpsFeed();
    _noiseSubject?.close();
    _noiseSubject = null;
    _networkSubject?.close();
    _networkSubject = null;
    _gpsSubject?.close();
    _gpsSubject = null;
  }
}
