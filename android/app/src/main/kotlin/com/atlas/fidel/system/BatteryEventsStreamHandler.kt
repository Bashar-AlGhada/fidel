package com.atlas.fidel.system

import android.content.Context
import android.content.Intent
import android.os.BatteryManager
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.atomic.AtomicBoolean

/** 1 Hz battery stream: percent + best-effort vitals (see payload keys). */
class BatteryEventsStreamHandler(private val context: Context) : EventChannel.StreamHandler {
  private val mainHandler = Handler(Looper.getMainLooper())
  private val active = AtomicBoolean(false)

  private var sink: EventChannel.EventSink? = null
  private val ticker = object : Runnable {
    override fun run() {
      if (!active.get()) return
      try {
        val bm = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val capacityPct = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        // Some OEMs report Int.MIN_VALUE when unknown; clamp to 0 so the
        // Dart side never sees garbage.
        val pct = if (capacityPct == Int.MIN_VALUE) 0 else capacityPct

        // Best-effort vitals; several OEMs report 0/Int.MIN_VALUE here.
        val voltageMicroVolts = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_VOLTAGE)
        val currentMicroAmps = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
        val chargedCounter = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER)

        val sticky = try {
          context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        } catch (_: Exception) {
          null
        }
        val tempTenthsC =
          sticky?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE) ?: Int.MIN_VALUE
        val status = sticky?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val plugged = sticky?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0

        // uV -> V.
        val volts = if (voltageMicroVolts > 0) voltageMicroVolts / 1_000_000.0 else null
        val amps = if (currentMicroAmps != Int.MIN_VALUE && currentMicroAmps != 0) {
          currentMicroAmps.toDouble()
        } else {
          null
        }
        val tempC = if (tempTenthsC != Int.MIN_VALUE) tempTenthsC / 10.0 else null

        sink?.success(
          mapOf(
            "percent" to pct,
            "voltageV" to volts,
            "currentMicroAmps" to amps,
            "temperatureC" to tempC,
            // uAh -> mAh.
            "capacityMah" to if (chargedCounter > 0) chargedCounter / 1000.0 else null,
            "charging" to (status == BatteryManager.BATTERY_STATUS_CHARGING ||
              status == BatteryManager.BATTERY_STATUS_FULL),
            "plugged" to (plugged != 0),
            // V * uA -> W.
            "watts" to if (volts != null && amps != null) (volts * amps / 1_000_000.0) else null,
          )
        )
      } catch (_: Exception) {
        Unit
      }
      mainHandler.postDelayed(this, 1000)
    }
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    sink = events
    active.set(true)
    mainHandler.post(ticker)
  }

  override fun onCancel(arguments: Any?) {
    // Cancel any pending post; a surviving tick would outlive `active`
    // on a rapid re-listen.
    mainHandler.removeCallbacks(ticker)
    active.set(false)
    sink = null
  }
}
