import '../../platform/android_bridge.dart';

class AndroidSystemDatasource {
  Stream<Map<String, dynamic>> batteryRaw() => AndroidBridge.batteryStream();
  Stream<Map<String, dynamic>> memoryRaw() => AndroidBridge.memoryStream();
  Stream<Map<String, dynamic>> cpuRaw() => AndroidBridge.cpuStream();

  Future<Map<String, dynamic>> deviceSnapshotResult() =>
      AndroidBridge.deviceSnapshot();

  Future<Map<String, dynamic>> buildSnapshotResult() =>
      AndroidBridge.buildSnapshot();

  Future<Map<String, dynamic>> displaySnapshotResult() =>
      AndroidBridge.displaySnapshot();

  Future<Map<String, dynamic>> memoryStorageSnapshotResult() =>
      AndroidBridge.memoryStorageSnapshot();

  Future<Map<String, dynamic>> batterySnapshotResult() =>
      AndroidBridge.batterySnapshot();

  Future<Map<String, dynamic>> camerasSnapshotResult() =>
      AndroidBridge.camerasSnapshot();

  Future<Map<String, dynamic>> securitySnapshotResult() =>
      AndroidBridge.securitySnapshot();

  Future<Map<String, dynamic>> codecsSnapshotResult() =>
      AndroidBridge.codecsSnapshot();

  Future<Map<String, dynamic>> cellularSimSnapshotResult() =>
      AndroidBridge.cellularSimSnapshot();

  Future<Map<String, dynamic>> widiMiracastSnapshotResult() =>
      AndroidBridge.widiMiracastSnapshot();

  Future<Map<String, dynamic>> exportInputsSnapshotResult({
    bool includeLastKnownSensors = false,
    int maxSensorSamples = 0,
  }) => AndroidBridge.exportInputsSnapshot(
    includeLastKnownSensors: includeLastKnownSensors,
    maxSensorSamples: maxSensorSamples,
  );

  Stream<Map<String, dynamic>> sensorEventsRaw({int? samplingPeriodUs}) =>
      AndroidBridge.sensorEvents(samplingPeriodUs: samplingPeriodUs);

  Stream<Map<String, dynamic>> thermalEventsRaw() =>
      AndroidBridge.thermalEvents();
}
