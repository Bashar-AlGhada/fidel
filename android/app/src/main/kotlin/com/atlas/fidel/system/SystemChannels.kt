package com.atlas.fidel.system

import android.content.Context
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

class SystemChannels(private val context: Context) {
  private val methodsChannelName = "com.atlas.fidel/system_methods"
  private val cpuEventsChannelName = "com.atlas.fidel/cpu_events"
  private val memoryEventsChannelName = "com.atlas.fidel/memory_events"
  private val batteryEventsChannelName = "com.atlas.fidel/battery_events"
  private val sensorEventsChannelName = "com.atlas.fidel/sensor_events"
  private val thermalEventsChannelName = "com.atlas.fidel/thermal_events"
  private val gnssEventsChannelName = "com.atlas.fidel/gnss_events"
  private val noiseEventsChannelName = "com.atlas.fidel/noise_events"
  private val networkEventsChannelName = "com.atlas.fidel/network_events"

  private val metadataSnapshotProvider = MetadataSnapshotProvider(context)
  private val sensorEventsStreamHandler = SensorEventsStreamHandler(context)
  private val thermalEventsStreamHandler = ThermalEventsStreamHandler(context, metadataSnapshotProvider)
  private val noiseEventsStreamHandler = NoiseEventsStreamHandler()
  private val batteryEventsStreamHandler = BatteryEventsStreamHandler(context)
  private val memoryEventsStreamHandler = MemoryEventsStreamHandler(context)
  private val cpuEventsStreamHandler = CpuEventsStreamHandler(context)
  private val networkEventsStreamHandler = NetworkEventsStreamHandler(context)
  private val gnssEventsStreamHandler = GnssEventsStreamHandler(context)

  fun register(engine: FlutterEngine) {
    MethodChannel(engine.dartExecutor.binaryMessenger, methodsChannelName)
      .setMethodCallHandler { call, result ->
        try {
          when (call.method) {
            "getDeviceInfo" -> result.success(
              mapOf(
                "manufacturer" to Build.MANUFACTURER,
                "model" to Build.MODEL,
                "sdkInt" to Build.VERSION.SDK_INT
              )
            )
            "getDeviceSnapshot" -> result.success(metadataSnapshotProvider.deviceSnapshot())
            "getBuildSnapshot" -> result.success(metadataSnapshotProvider.buildSnapshot())
            "getDisplaySnapshot" -> result.success(metadataSnapshotProvider.displaySnapshot())
            "getBatterySnapshot" -> result.success(metadataSnapshotProvider.batterySnapshot())
            "getCamerasSnapshot" -> result.success(metadataSnapshotProvider.camerasSnapshot())
            "getSecuritySnapshot" -> result.success(metadataSnapshotProvider.securitySnapshot())
            "getCodecsSnapshot" -> result.success(metadataSnapshotProvider.codecsSnapshot())
            "getMemoryStorageSnapshot" -> result.success(metadataSnapshotProvider.memoryStorageSnapshot())
            "getCellularSimSnapshot" -> result.success(metadataSnapshotProvider.cellularSimSnapshot())
            "getWidiMiracastSnapshot" -> result.success(metadataSnapshotProvider.widiMiracastSnapshot())
            "getExportInputsSnapshot" -> {
              val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
              val includeLastKnownSensors = (args["includeLastKnownSensors"] as? Boolean) == true
              val maxSensorSamples = (args["maxSensorSamples"] as? Number)?.toInt() ?: 0

              result.success(
                mapOf(
                  "device" to metadataSnapshotProvider.deviceSnapshot(),
                  "build" to metadataSnapshotProvider.buildSnapshot(),
                  "display" to metadataSnapshotProvider.displaySnapshot(),
                  "memoryStorage" to metadataSnapshotProvider.memoryStorageSnapshot(),
                  "battery" to metadataSnapshotProvider.batterySnapshot(),
                  "cameras" to metadataSnapshotProvider.camerasSnapshot(),
                  "cellularSim" to metadataSnapshotProvider.cellularSimSnapshot(),
                  "security" to metadataSnapshotProvider.securitySnapshot(),
                  "codecs" to metadataSnapshotProvider.codecsSnapshot(),
                  "widiMiracast" to metadataSnapshotProvider.widiMiracastSnapshot(),
                  "sensors" to sensorEventsStreamHandler.exportSnapshot(
                    includeLastKnown = includeLastKnownSensors,
                    maxSamples = maxSensorSamples,
                  ),
                  "thermal" to thermalEventsStreamHandler.exportSnapshot(),
                )
              )
            }
            "setBleScanning" -> {
              val on = (call.arguments as? Map<*, *>)?.get("enabled") as? Boolean == true
              networkEventsStreamHandler.setBleScanning(on)
              result.success(null)
            }
            else -> result.notImplemented()
          }
        } catch (e: Exception) {
          result.error("unavailable", e.message, null)
        }
      }

    EventChannel(engine.dartExecutor.binaryMessenger, cpuEventsChannelName)
      .setStreamHandler(cpuEventsStreamHandler)
    EventChannel(engine.dartExecutor.binaryMessenger, memoryEventsChannelName)
      .setStreamHandler(memoryEventsStreamHandler)
    EventChannel(engine.dartExecutor.binaryMessenger, batteryEventsChannelName)
      .setStreamHandler(batteryEventsStreamHandler)
    EventChannel(engine.dartExecutor.binaryMessenger, sensorEventsChannelName)
      .setStreamHandler(sensorEventsStreamHandler)
    EventChannel(engine.dartExecutor.binaryMessenger, thermalEventsChannelName)
      .setStreamHandler(thermalEventsStreamHandler)
    EventChannel(engine.dartExecutor.binaryMessenger, noiseEventsChannelName)
      .setStreamHandler(noiseEventsStreamHandler)
    EventChannel(engine.dartExecutor.binaryMessenger, gnssEventsChannelName)
      .setStreamHandler(gnssEventsStreamHandler)
    EventChannel(engine.dartExecutor.binaryMessenger, networkEventsChannelName)
      .setStreamHandler(networkEventsStreamHandler)
  }

  fun dispose() {
    batteryEventsStreamHandler.stop()
    memoryEventsStreamHandler.stop()
    cpuEventsStreamHandler.stop()
    sensorEventsStreamHandler.stop()
    thermalEventsStreamHandler.stop()
    noiseEventsStreamHandler.stop()
    gnssEventsStreamHandler.stop()
    networkEventsStreamHandler.stop()
  }
}