import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

  static Map<String, dynamic> _coerceMap(Object? value) {
    if (value is Map) return value.cast<String, dynamic>();
    return const {};
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
      return _ok(_coerceMap(result));
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

  static Future<Map<String, dynamic>> getDeviceInfo() async {
    final result = await getDeviceInfoResult();
    if (result['ok'] != true) return const {};
    return _coerceMap(result['data']);
  }

  static Future<Map<String, dynamic>> getDeviceInfoResult() =>
      _invokeResultMap('getDeviceInfo');

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

    return _sensorEvents
        .receiveBroadcastStream(
          samplingPeriodUs != null && samplingPeriodUs > 0
              ? <String, Object>{'samplingPeriodUs': samplingPeriodUs}
              : null,
        )
        .transform(
          StreamTransformer<Object?, Map<String, dynamic>>.fromHandlers(
            handleData: (data, sink) => sink.add(_ok(_coerceMap(data))),
            handleError: (error, stack, sink) {
              final payload = switch (error) {
                PlatformException e => _err(
                  code: e.code,
                  message: e.message,
                  details: e.details,
                ),
                MissingPluginException e => _err(
                  code: 'missing_plugin',
                  message: e.message ?? 'Missing platform implementation.',
                ),
                _ => _err(code: 'stream_error', message: error.toString()),
              };
              sink.add(payload);
            },
          ),
        );
  }

  static Stream<Map<String, dynamic>> thermalEvents() {
    if (!_isAndroid) return const Stream.empty();

    return _thermalEvents.receiveBroadcastStream().transform(
      StreamTransformer<Object?, Map<String, dynamic>>.fromHandlers(
        handleData: (data, sink) => sink.add(_ok(_coerceMap(data))),
        handleError: (error, stack, sink) {
          final payload = switch (error) {
            PlatformException e => _err(
              code: e.code,
              message: e.message,
              details: e.details,
            ),
            MissingPluginException e => _err(
              code: 'missing_plugin',
              message: e.message ?? 'Missing platform implementation.',
            ),
            _ => _err(code: 'stream_error', message: error.toString()),
          };
          sink.add(payload);
        },
      ),
    );
  }

  static Stream<Map<String, dynamic>> cpuStream() {
    if (!_isAndroid) return const Stream.empty();
    return _cpuEvents.receiveBroadcastStream().map(
      (e) => (e as Map).cast<String, dynamic>(),
    );
  }

  static Stream<Map<String, dynamic>> memoryStream() {
    if (!_isAndroid) return const Stream.empty();
    return _memoryEvents.receiveBroadcastStream().map(
      (e) => (e as Map).cast<String, dynamic>(),
    );
  }

  static Stream<Map<String, dynamic>> batteryStream() {
    if (!_isAndroid) return const Stream.empty();
    return _batteryEvents.receiveBroadcastStream().map(
      (e) => (e as Map).cast<String, dynamic>(),
    );
  }
}
