package com.atlas.fidel.system

import android.content.Context
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
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
              result.success(networkEventsStreamHandler.setBleScanning(on))
            }
            "testVibration" -> {
              val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
              val patternMs = (args["patternMs"] as? List<*>)
                ?.mapNotNull { (it as? Number)?.toInt() } ?: emptyList()
              val amplitudes = (args["amplitudes"] as? List<*>)
                ?.mapNotNull { (it as? Number)?.toInt() }
              result.success(testVibration(patternMs, amplitudes))
            }
            "setTorch" -> {
              val enabled = (call.arguments as? Map<*, *>)?.get("enabled") as? Boolean == true
              result.success(setTorch(enabled))
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

  /** Vibration tester; returns `{ok, reason}` for the Dart caller. */
  private fun testVibration(patternMs: List<Int>, amplitudes: List<Int>?): Map<String, Any?> {
    if (patternMs.isEmpty()) return mapOf("ok" to false, "reason" to "invalid_args")

    val vibrator = if (Build.VERSION.SDK_INT >= 31) {
      (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
        ?.defaultVibrator ?: return mapOf("ok" to false, "reason" to "unsupported")
    } else {
      @Suppress("DEPRECATION")
      context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        ?: return mapOf("ok" to false, "reason" to "unsupported")
    }
    if (!vibrator.hasVibrator()) return mapOf("ok" to false, "reason" to "unsupported")

    return try {
      if (patternMs.size == 1) {
        vibrator.vibrate(patternMs[0].toLong())
      } else {
        // Amplitude control needs API 26; null amplitudes mean "default
        // strength" inside createWaveform.
        val resolved = amplitudes
          ?.takeIf { Build.VERSION.SDK_INT >= 26 && it.size == patternMs.size }
          ?.toIntArray()
        vibrator.vibrate(
          VibrationEffect.createWaveform(
            patternMs.map { it.toLong() }.toLongArray(),
            resolved,
            -1,
          )
        )
      }
      mapOf("ok" to true, "reason" to null)
    } catch (_: SecurityException) {
      mapOf("ok" to false, "reason" to "permission_denied")
    } catch (_: Exception) {
      mapOf("ok" to false, "reason" to "unsupported")
    }
  }

  /** Flashlight tester; returns `{ok, reason}` for the Dart caller. */
  private fun setTorch(enabled: Boolean): Map<String, Any?> {
    val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as? CameraManager
      ?: return mapOf("ok" to false, "reason" to "torch_unavailable")

    val flashCameraId = try {
      cameraManager.cameraIdList.firstOrNull { id ->
        try {
          cameraManager.getCameraCharacteristics(id)
            .get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
        } catch (_: Exception) {
          false
        }
      }
    } catch (_: Exception) {
      null
    } ?: return mapOf("ok" to false, "reason" to "torch_unavailable")

    return try {
      cameraManager.setTorchMode(flashCameraId, enabled)
      mapOf("ok" to true, "reason" to null)
    } catch (_: CameraAccessException) {
      mapOf("ok" to false, "reason" to "camera_error")
    } catch (_: IllegalArgumentException) {
      mapOf("ok" to false, "reason" to "torch_unavailable")
    } catch (_: Exception) {
      mapOf("ok" to false, "reason" to "camera_error")
    }
  }
}
