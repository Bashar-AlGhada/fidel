package com.atlas.fidel.system

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.atomic.AtomicBoolean

class ThermalEventsStreamHandler(
  private val context: Context,
  private val metadataSnapshotProvider: MetadataSnapshotProvider,
) : EventChannel.StreamHandler {
  private val mainHandler = Handler(Looper.getMainLooper())
  private val active = AtomicBoolean(false)
  private var sink: EventChannel.EventSink? = null

  private var lastKnown: Map<String, Any?> = emptyMap()
  private var thermalStatusListener: PowerManager.OnThermalStatusChangedListener? = null
  private var thermalStatus: Int? = null

  private val ticker = object : Runnable {
    override fun run() {
      if (!active.get()) return
      emitSnapshot()
      mainHandler.postDelayed(this, 1000)
    }
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    stop()
    sink = events
    active.set(true)

    val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
    thermalStatus = if (Build.VERSION.SDK_INT >= 29) pm.currentThermalStatus else null

    if (Build.VERSION.SDK_INT >= 29) {
      val listener = PowerManager.OnThermalStatusChangedListener { status ->
        thermalStatus = status
        emitSnapshot()
      }
      thermalStatusListener = listener
      try {
        pm.addThermalStatusListener(context.mainExecutor, listener)
      } catch (_: Exception) {
        thermalStatusListener = null
      }
    }

    mainHandler.post(ticker)
  }

  override fun onCancel(arguments: Any?) {
    stop()
  }

  fun stop() {
    if (!active.getAndSet(false)) {
      sink = null
      return
    }

    mainHandler.removeCallbacks(ticker)

    val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
    val listener = thermalStatusListener
    if (listener != null && Build.VERSION.SDK_INT >= 29) {
      try {
        pm.removeThermalStatusListener(listener)
      } catch (_: Exception) {
        Unit
      }
    }

    thermalStatusListener = null
    sink = null
  }

  fun exportSnapshot(): Map<String, Any?> {
    return lastKnown
  }

  private fun emitSnapshot() {
    val payload = mutableMapOf<String, Any?>(
      "kind" to "thermal",
      "timestampMs" to System.currentTimeMillis(),
      "thermalStatus" to thermalStatus,
    )

    val temps = metadataSnapshotProvider.bestEffortThermalTemperatures()
    payload["temperatures"] = temps

    lastKnown = payload.toMap()

    mainHandler.post {
      sink?.success(lastKnown)
    }
  }
}

