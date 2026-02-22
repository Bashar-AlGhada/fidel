package com.atlas.fidel.system

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.util.ArrayDeque
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

class SensorEventsStreamHandler(private val context: Context) : EventChannel.StreamHandler {
  private val mainHandler = Handler(Looper.getMainLooper())
  private val active = AtomicBoolean(false)
  private val lastKnownByKey = ConcurrentHashMap<String, Map<String, Any?>>()
  private val samplesByKey = ConcurrentHashMap<String, ArrayDeque<Map<String, Any?>>>()

  private var sink: EventChannel.EventSink? = null
  private var handlerThread: HandlerThread? = null
  private var sensorHandler: Handler? = null
  private var sensorManager: SensorManager? = null

  private val listener = object : SensorEventListener {
    override fun onSensorChanged(event: SensorEvent) {
      if (!active.get()) return
      val key = sensorKey(event.sensor)
      val payload = mapOf(
        "kind" to "reading",
        "key" to key,
        "sensorType" to event.sensor.type,
        "timestampNs" to event.timestamp,
        "timestampMs" to System.currentTimeMillis(),
        "accuracy" to event.accuracy,
        "values" to event.values.map { it.toDouble() },
      )

      lastKnownByKey[key] = payload
      val deque = samplesByKey.getOrPut(key) { ArrayDeque() }
      synchronized(deque) {
        deque.addLast(payload)
        while (deque.size > 256) deque.removeFirst()
      }

      mainHandler.post {
        sink?.success(payload)
      }
    }

    override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {
      if (!active.get()) return
      val key = sensorKey(sensor)
      val payload = mapOf(
        "kind" to "accuracy",
        "key" to key,
        "sensorType" to sensor.type,
        "timestampMs" to System.currentTimeMillis(),
        "accuracy" to accuracy,
      )
      mainHandler.post {
        sink?.success(payload)
      }
    }
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    stop()

    sink = events
    active.set(true)

    handlerThread = HandlerThread("fidel_sensors").also { it.start() }
    sensorHandler = Handler(handlerThread!!.looper)
    sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager

    val args = (arguments as? Map<*, *>)?.entries?.associate { it.key.toString() to it.value } ?: emptyMap()
    val samplingPeriodUs = (args["samplingPeriodUs"] as? Number)?.toInt()?.takeIf { it > 0 } ?: 200_000

    val sensors = sensorManager?.getSensorList(Sensor.TYPE_ALL).orEmpty()
    val capabilities = sensors.map { sensor ->
      mapOf(
        "key" to sensorKey(sensor),
        "name" to sensor.name,
        "vendor" to sensor.vendor,
        "type" to sensor.type,
        "version" to sensor.version,
        "maxRange" to sensor.maximumRange.toDouble(),
        "resolution" to sensor.resolution.toDouble(),
        "powerMilliAmp" to sensor.power.toDouble(),
        "minDelayUs" to sensor.minDelay,
      )
    }

    mainHandler.post {
      sink?.success(mapOf("kind" to "capabilities", "sensors" to capabilities))
    }

    sensors.forEach { sensor ->
      try {
        sensorManager?.registerListener(listener, sensor, samplingPeriodUs, sensorHandler)
      } catch (_: Exception) {
        Unit
      }
    }
  }

  override fun onCancel(arguments: Any?) {
    stop()
  }

  fun stop() {
    if (!active.getAndSet(false)) {
      sink = null
      return
    }

    try {
      sensorManager?.unregisterListener(listener)
    } catch (_: Exception) {
      Unit
    }

    sensorManager = null
    sink = null

    try {
      handlerThread?.quitSafely()
    } catch (_: Exception) {
      try {
        handlerThread?.quit()
      } catch (_: Exception) {
        Unit
      }
    }

    handlerThread = null
    sensorHandler = null
  }

  fun exportSnapshot(includeLastKnown: Boolean, maxSamples: Int): Map<String, Any?> {
    val lastKnown = if (includeLastKnown) lastKnownByKey.values.toList() else emptyList()
    val samples = if (maxSamples > 0) {
      samplesByKey.entries.map { (key, deque) ->
        val items = synchronized(deque) { deque.toList().takeLast(maxSamples.coerceAtMost(256)) }
        mapOf("key" to key, "samples" to items)
      }
    } else emptyList()

    return mapOf(
      "lastKnown" to lastKnown,
      "samples" to samples,
    )
  }

  private fun sensorKey(sensor: Sensor): String {
    return "${sensor.type}:${sensor.name}:${sensor.vendor}"
  }
}

