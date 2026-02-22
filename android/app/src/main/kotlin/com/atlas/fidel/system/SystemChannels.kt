package com.atlas.fidel.system

import android.app.ActivityManager
import android.content.Context
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.RandomAccessFile
import java.util.concurrent.atomic.AtomicBoolean

class SystemChannels(private val context: Context) {
  private val methodsChannelName = "com.atlas.fidel/system_methods"
  private val cpuEventsChannelName = "com.atlas.fidel/cpu_events"
  private val memoryEventsChannelName = "com.atlas.fidel/memory_events"
  private val batteryEventsChannelName = "com.atlas.fidel/battery_events"
  private val sensorEventsChannelName = "com.atlas.fidel/sensor_events"
  private val thermalEventsChannelName = "com.atlas.fidel/thermal_events"

  private val metadataSnapshotProvider = MetadataSnapshotProvider(context)
  private val sensorEventsStreamHandler = SensorEventsStreamHandler(context)
  private val thermalEventsStreamHandler = ThermalEventsStreamHandler(context, metadataSnapshotProvider)

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
            else -> result.notImplemented()
          }
        } catch (e: Exception) {
          result.error("unavailable", e.message, null)
        }
      }

    wireBatteryEvents(engine)
    wireMemoryEvents(engine)
    wireCpuEvents(engine)
    wireSensorEvents(engine)
    wireThermalEvents(engine)
  }

  fun dispose() {
    sensorEventsStreamHandler.stop()
    thermalEventsStreamHandler.stop()
  }

  private fun wireBatteryEvents(engine: FlutterEngine) {
    EventChannel(engine.dartExecutor.binaryMessenger, batteryEventsChannelName)
      .setStreamHandler(object : EventChannel.StreamHandler {
        private val handler = Handler(Looper.getMainLooper())
        private val active = AtomicBoolean(false)
        private var sink: EventChannel.EventSink? = null

        private val ticker = object : Runnable {
          override fun run() {
            if (!active.get()) return
            val bm = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            val pct = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            sink?.success(mapOf("percent" to pct))
            handler.postDelayed(this, 1000)
          }
        }

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
          sink = events
          active.set(true)
          handler.post(ticker)
        }

        override fun onCancel(arguments: Any?) {
          active.set(false)
          sink = null
        }
      })
  }

  private fun wireMemoryEvents(engine: FlutterEngine) {
    EventChannel(engine.dartExecutor.binaryMessenger, memoryEventsChannelName)
      .setStreamHandler(object : EventChannel.StreamHandler {
        private val handler = Handler(Looper.getMainLooper())
        private val active = AtomicBoolean(false)
        private var sink: EventChannel.EventSink? = null

        private val ticker = object : Runnable {
          override fun run() {
            if (!active.get()) return
            val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val mi = ActivityManager.MemoryInfo()
            am.getMemoryInfo(mi)
            sink?.success(mapOf("availBytes" to mi.availMem, "totalBytes" to mi.totalMem))
            handler.postDelayed(this, 1000)
          }
        }

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
          sink = events
          active.set(true)
          handler.post(ticker)
        }

        override fun onCancel(arguments: Any?) {
          active.set(false)
          sink = null
        }
      })
  }

  private fun wireSensorEvents(engine: FlutterEngine) {
    EventChannel(engine.dartExecutor.binaryMessenger, sensorEventsChannelName)
      .setStreamHandler(sensorEventsStreamHandler)
  }

  private fun wireThermalEvents(engine: FlutterEngine) {
    EventChannel(engine.dartExecutor.binaryMessenger, thermalEventsChannelName)
      .setStreamHandler(thermalEventsStreamHandler)
  }

  private fun wireCpuEvents(engine: FlutterEngine) {
    EventChannel(engine.dartExecutor.binaryMessenger, cpuEventsChannelName)
      .setStreamHandler(object : EventChannel.StreamHandler {
        private val handler = Handler(Looper.getMainLooper())
        private val active = AtomicBoolean(false)
        private var sink: EventChannel.EventSink? = null
        private var lastTotal: Long = 0
        private var lastIdle: Long = 0

        private val ticker = object : Runnable {
          override fun run() {
            if (!active.get()) return
            try {
              val stat = readProcStat()
              val total = stat.total
              val idle = stat.idle
              val diffTotal = total - lastTotal
              val diffIdle = idle - lastIdle
              val usage = if (diffTotal <= 0) 0.0 else (diffTotal - diffIdle).toDouble() / diffTotal.toDouble()

              lastTotal = total
              lastIdle = idle

              sink?.success(mapOf("usageRatio" to usage, "cores" to Runtime.getRuntime().availableProcessors()))
            } catch (_: Exception) {
              sink?.success(mapOf("usageRatio" to 0.0, "cores" to Runtime.getRuntime().availableProcessors()))
            }
            handler.postDelayed(this, 1000)
          }
        }

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
          sink = events
          active.set(true)
          val initial = readProcStat()
          lastTotal = initial.total
          lastIdle = initial.idle
          handler.postDelayed(ticker, 1000)
        }

        override fun onCancel(arguments: Any?) {
          active.set(false)
          sink = null
        }
      })
  }

  private data class CpuStat(val total: Long, val idle: Long)

  private fun readProcStat(): CpuStat {
    RandomAccessFile("/proc/stat", "r").use { raf ->
      val line = raf.readLine() ?: ""
      val parts = line.split(Regex("\\s+")).filter { it.isNotBlank() }
      if (parts.size < 8) return CpuStat(0, 0)
      val user = parts[1].toLongOrNull() ?: 0
      val nice = parts[2].toLongOrNull() ?: 0
      val system = parts[3].toLongOrNull() ?: 0
      val idle = parts[4].toLongOrNull() ?: 0
      val iowait = parts[5].toLongOrNull() ?: 0
      val irq = parts[6].toLongOrNull() ?: 0
      val softirq = parts[7].toLongOrNull() ?: 0
      val total = user + nice + system + idle + iowait + irq + softirq
      return CpuStat(total = total, idle = idle + iowait)
    }
  }
}
