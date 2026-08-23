package com.atlas.fidel.system

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.roundToInt

/** 1 Hz battery stream: percent + best-effort vitals (see payload keys). */
class BatteryEventsStreamHandler(private val context: Context) : EventChannel.StreamHandler {
  private companion object {
    // Sticky-intent extra keys as literals: immune to compileSdk gaps for
    // the newer BatteryManager property constants.
    const val EXTRA_VOLTAGE_UV = "voltage"
    const val EXTRA_CURRENT_UA = "current_now"
    const val EXTRA_CHARGE_COUNTER_UAH = "charge_counter"
  }

  private val mainHandler = Handler(Looper.getMainLooper())
  private val active = AtomicBoolean(false)

  private var sink: EventChannel.EventSink? = null
  private val ticker = object : Runnable {
    override fun run() {
      if (!active.get()) return
      try {
        // The sticky ACTION_BATTERY_CHANGED broadcast is the most portable
        // source across OEMs; property getters often report MIN_VALUE.
        val sticky = try {
          context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        } catch (_: Exception) {
          null
        }

        val level = sticky?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = sticky?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val pct =
            if (level >= 0 && scale > 0) (level * 100f / scale).roundToInt()
            else 0

        val voltageMicroVolts = sticky?.getIntExtra(EXTRA_VOLTAGE_UV, -1) ?: -1
        val currentMicroAmps = sticky?.getIntExtra(EXTRA_CURRENT_UA, Int.MIN_VALUE)
            ?: Int.MIN_VALUE
        val chargedCounter =
            sticky?.getIntExtra(EXTRA_CHARGE_COUNTER_UAH, -1) ?: -1

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

  /** Stops the ticker; safe to call multiple times. */
  fun stop() {
    mainHandler.removeCallbacks(ticker)
    active.set(false)
    sink = null
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    sink = events
    active.set(true)
    mainHandler.post(ticker)
  }

  override fun onCancel(arguments: Any?) {
    stop()
  }
}
