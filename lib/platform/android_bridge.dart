import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/utils/map_coercion.dart' show coerceMap;

class AndroidBridge {
  AndroidBridge._();

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static const MethodChannel _methods = MethodChannel(
    'com.atlas.fidel/system_methods',
  );

  static const EventChannel _cpuEvents = EventChannel(
    'com.atlas.fidel/cpu_events',
  );
  static const EventChannel _memoryEvents = EventChannel(
    'com.atlas.fidel/memory_events',
  );
  static const EventChannel _batteryEvents = EventChannel(
    'com.atlas.fidel/battery_events',
  );

  static const EventChannel _sensorEvents = EventChannel(
    'com.atlas.fidel/sensor_events',
  );
  static const EventChannel _thermalEvents = EventChannel(
    'com.atlas.fidel/thermal_events',
  );
  static const EventChannel _noiseEvents = EventChannel(
    'com.atlas.fidel/noise_events',
  );
  static const EventChannel _networkEvents = EventChannel(
    'com.atlas.fidel/network_events',
  );
  static const EventChannel _gnssEvents = EventChannel(
    'com.atlas.fidel/gnss_events',
  );

  static Map<String, dynamic> _ok(Map<String, dynamic> data) => {
    'ok': true,
    'data': data,
  };

  static Map<String, dynamic> _err({
    required String code,
    String? message,
    Object? details,
  }) => {
    'ok': false,
    'error': <String, dynamic>{
      'code': code,
      'message': message ?? '',
      'details': _sanitize(details),
    },
  };

  static Object? _sanitize(Object? value) {
    return switch (value) {
      null => null,
      bool _ || num _ || String _ => value,
      Map _ => value,
      List _ => value,
      _ => value.toString(),
    };
  }

  /// One cached broadcast stream per channel+arguments.
  ///
  /// [EventChannel.receiveBroadcastStream] registers a single binary
  /// handler per channel name, so creating fresh streams per call lets an
  /// overlapping cancel from consumer A unregister the handler that
  /// consumer B is listening on — silently killing the feed. Sharing one
  /// cached broadcast stream makes every listener a plain Dart-level
  /// subscriber whose cancel cannot touch the native side while others
  /// remain attached.
  static final Map<String, Stream<Map<String, dynamic>>> _streamCache = {};

  static Stream<Map<String, dynamic>> _cachedEventStream(
    EventChannel channel, {
    Map<String, Object>? arguments,
  }) {
    final key = '${channel.name}|$arguments';
    return _streamCache.putIfAbsent(key, () {
      return _guardedStream(
        channel.receiveBroadcastStream(arguments),
        toMap: coerceMap,
      );
    });
  }

  /// Normalizes a broadcast stream into `Map` data events and real stream
  /// errors. Errors are surfaced via the error channel so consumers can
  /// never mistake a failure for a valid payload.
  static Stream<Map<String, dynamic>> _guardedStream(
    Stream<Object?> raw, {
    required Map<String, dynamic> Function(Object? event) toMap,
  }) {
    return raw.transform(
      StreamTransformer<Object?, Map<String, dynamic>>.fromHandlers(
        handleData: (data, sink) => sink.add(toMap(data)),
        handleError: (error, stack, sink) =>
            sink.addError(_asPlatformException(error)),
      ),
    );
  }

  static PlatformException _asPlatformException(Object error) {
    return switch (error) {
      PlatformException e => e,
      MissingPluginException e => PlatformException(
        code: 'missing_plugin',
        message: e.message ?? 'Missing platform implementation.',
      ),
      _ => PlatformException(code: 'stream_error', message: error.toString()),
    };
  }

  static Future<Map<String, dynamic>> _invokeResultMap(
    String method, {
    Object? arguments,
  }) async {
    if (!_isAndroid) {
      return _err(
        code: 'unsupported_platform',
        message:
            'Android platform channels are not available on this platform.',
      );
    }

    try {
      final result = await _methods.invokeMethod<Object?>(method, arguments);
      return _ok(coerceMap(result));
    } on MissingPluginException catch (e) {
      return _err(
        code: 'missing_plugin',
        message: e.message ?? 'Missing platform implementation.',
      );
    } on PlatformException catch (e) {
      return _err(code: e.code, message: e.message, details: e.details);
    } catch (e) {
      return _err(code: 'unexpected', message: e.toString());
    }
  }

  static Future<Map<String, dynamic>> deviceSnapshot() =>
      _invokeResultMap('getDeviceSnapshot');

  static Future<Map<String, dynamic>> buildSnapshot() =>
      _invokeResultMap('getBuildSnapshot');

  static Future<Map<String, dynamic>> displaySnapshot() =>
      _invokeResultMap('getDisplaySnapshot');

  static Future<Map<String, dynamic>> memoryStorageSnapshot() =>
      _invokeResultMap('getMemoryStorageSnapshot');

  static Future<Map<String, dynamic>> batterySnapshot() =>
      _invokeResultMap('getBatterySnapshot');

  static Future<Map<String, dynamic>> camerasSnapshot() =>
      _invokeResultMap('getCamerasSnapshot');

  static Future<Map<String, dynamic>> securitySnapshot() =>
      _invokeResultMap('getSecuritySnapshot');

  static Future<Map<String, dynamic>> codecsSnapshot() =>
      _invokeResultMap('getCodecsSnapshot');

  static Future<Map<String, dynamic>> cellularSimSnapshot() =>
      _invokeResultMap('getCellularSimSnapshot');

  static Future<Map<String, dynamic>> widiMiracastSnapshot() =>
      _invokeResultMap('getWidiMiracastSnapshot');

  static Future<Map<String, dynamic>> setBleScanning({required bool enabled}) =>
      _invokeResultMap('setBleScanning', arguments: {'enabled': enabled});

  /// Native contract: args {patternMs, amplitudes?} → payload
  /// {ok: bool, reason: String?}.
  static Future<Map<String, dynamic>> testVibration({
    required List<int> patternMs,
    List<int>? amplitudes,
  }) => _invokeResultMap(
    'testVibration',
    arguments: {'patternMs': patternMs, 'amplitudes': amplitudes},
  );

  /// Native contract: args {enabled} → payload {ok: bool, reason: String?}.
  static Future<Map<String, dynamic>> setTorch({required bool enabled}) =>
      _invokeResultMap('setTorch', arguments: {'enabled': enabled});

  static Future<Map<String, dynamic>> exportInputsSnapshot({
    bool includeLastKnownSensors = false,
    int maxSensorSamples = 0,
  }) => _invokeResultMap(
    'getExportInputsSnapshot',
    arguments: <String, Object>{
      'includeLastKnownSensors': includeLastKnownSensors,
      'maxSensorSamples': maxSensorSamples,
    },
  );

  static Stream<Map<String, dynamic>> sensorEvents({int? samplingPeriodUs}) {
    if (!_isAndroid) return const Stream.empty();

    final hasPeriod = samplingPeriodUs != null && samplingPeriodUs > 0;
    return _cachedEventStream(
      _sensorEvents,
      arguments: hasPeriod
          ? <String, Object>{'samplingPeriodUs': samplingPeriodUs}
          : null,
    );
  }

  static Stream<Map<String, dynamic>> thermalEvents() {
    if (!_isAndroid) return const Stream.empty();

    return _cachedEventStream(_thermalEvents);
  }

  static Stream<Map<String, dynamic>> cpuStream() {
    if (!_isAndroid) return const Stream.empty();
    return _cachedEventStream(_cpuEvents);
  }

  static Stream<Map<String, dynamic>> memoryStream() {
    if (!_isAndroid) return const Stream.empty();
    return _cachedEventStream(_memoryEvents);
  }

  static Stream<Map<String, dynamic>> batteryStream() {
    if (!_isAndroid) return const Stream.empty();
    return _cachedEventStream(_batteryEvents);
  }

  static Stream<Map<String, dynamic>> noiseEvents() {
    if (!_isAndroid) return const Stream.empty();
    return _cachedEventStream(_noiseEvents);
  }

  static Stream<Map<String, dynamic>> networkEvents() {
    if (!_isAndroid) return const Stream.empty();
    return _cachedEventStream(_networkEvents);
  }

  static Stream<Map<String, dynamic>> gpsEvents() {
    if (!_isAndroid) return const Stream.empty();
    return _cachedEventStream(_gnssEvents);
  }
}
