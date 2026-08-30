package com.atlas.fidel.system

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.abs

/** 1 Hz battery stream: percent + best-effort vitals (see payload keys). */
class BatteryEventsStreamHandler(private val context: Context) : EventChannel.StreamHandler {
  private companion object {
    // Sticky-intent extra keys as literals: immune to compileSdk gaps for
    // the newer BatteryManager property constants.
    const val EXTRA_VOLTAGE_MV = "voltage"
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
        // source for percent/voltage/temperature across OEMs; scalar vitals
        // (currents, counters) come from the BatteryManager service getters.
        val sticky = try {
          context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        } catch (_: Exception) {
          null
        }
        val batteryManager = try {
          context.getSystemService(BatteryManager::class.java)
        } catch (_: Exception) {
          null
        }

        val level = sticky?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = sticky?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val percent =
            if (level >= 0 && scale > 0) level * 100.0 / scale
            else null

        // EXTRA_VOLTAGE carries millivolts despite the legacy naming.
        val voltageMilliVolts = sticky?.getIntExtra(EXTRA_VOLTAGE_MV, -1) ?: -1
        val volts = if (voltageMilliVolts > 0) voltageMilliVolts / 1000.0 else null

        val tempTenthsC =
          sticky?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE) ?: Int.MIN_VALUE
        val tempC = if (tempTenthsC != Int.MIN_VALUE) tempTenthsC / 10.0 else null

        val status = sticky?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val health = sticky?.getIntExtra(BatteryManager.EXTRA_HEALTH, -1) ?: -1
        val plugged = sticky?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0

        val currentMicroAmps =
          intProperty(batteryManager, BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
        val averageCurrentMicroAmps =
          intProperty(batteryManager, BatteryManager.BATTERY_PROPERTY_CURRENT_AVERAGE)
        val chargeCounterUah =
          intProperty(batteryManager, BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER)
        val energyCounterNwh =
          longProperty(batteryManager, BatteryManager.BATTERY_PROPERTY_ENERGY_COUNTER)

        sink?.success(
          mapOf(
            "percent" to percent,
            "voltageV" to volts,
            "currentMicroAmps" to currentMicroAmps,
            "averageCurrentMicroAmps" to averageCurrentMicroAmps,
            "temperatureC" to tempC,
            "capacityMah" to capacityMah(sticky),
            "chargeCounterUah" to chargeCounterUah,
            "energyCounterNwh" to energyCounterNwh,
            "charging" to (status == BatteryManager.BATTERY_STATUS_CHARGING ||
              status == BatteryManager.BATTERY_STATUS_FULL ||
              plugged != 0),
            "plugged" to (plugged != 0),
            "plugSource" to plugSource(plugged),
            "status" to statusLabel(status),
            "health" to healthLabel(health),
            // V * uA -> W.
            "watts" to if (volts != null && currentMicroAmps != null) {
              abs(volts * currentMicroAmps / 1_000_000.0)
            } else {
              null
            },
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

  // Legacy extra source kept for compatibility; null on most devices today.
  private fun capacityMah(sticky: Intent?): Double? {
    val uah = sticky?.getIntExtra(EXTRA_CHARGE_COUNTER_UAH, -1) ?: -1
    return if (uah > 0) uah / 1000.0 else null
  }

  /** Null for unsupported/error readings; legitimate 0 values are kept. */
  private fun intProperty(batteryManager: BatteryManager?, property: Int): Long? {
    return try {
      val value = batteryManager?.getIntProperty(property) ?: return null
      if (value == Int.MIN_VALUE) null else value.toLong()
    } catch (_: Exception) {
      null
    }
  }

  private fun longProperty(batteryManager: BatteryManager?, property: Int): Long? {
    return try {
      val value = batteryManager?.getLongProperty(property) ?: return null
      if (value == Long.MIN_VALUE) null else value
    } catch (_: Exception) {
      null
    }
  }

  private fun plugSource(plugged: Int): String? = when {
    plugged and BatteryManager.BATTERY_PLUGGED_AC != 0 -> "ac"
    plugged and BatteryManager.BATTERY_PLUGGED_USB != 0 -> "usb"
    plugged and BatteryManager.BATTERY_PLUGGED_WIRELESS != 0 -> "wireless"
    plugged and BatteryManager.BATTERY_PLUGGED_DOCK != 0 -> "dock"
    plugged == 0 -> "battery"
    else -> null
  }

  private fun statusLabel(status: Int): String? = when (status) {
    BatteryManager.BATTERY_STATUS_CHARGING -> "charging"
    BatteryManager.BATTERY_STATUS_FULL -> "full"
    BatteryManager.BATTERY_STATUS_DISCHARGING -> "discharging"
    BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "not_charging"
    BatteryManager.BATTERY_STATUS_UNKNOWN -> "unknown"
    else -> null
  }

  private fun healthLabel(health: Int): String? = when (health) {
    BatteryManager.BATTERY_HEALTH_GOOD -> "good"
    BatteryManager.BATTERY_HEALTH_OVERHEAT -> "overheat"
    BatteryManager.BATTERY_HEALTH_DEAD -> "dead"
    BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> "over_voltage"
    BatteryManager.BATTERY_HEALTH_UNSPECIFIED_FAILURE -> "failure"
    BatteryManager.BATTERY_HEALTH_COLD -> "cold"
    BatteryManager.BATTERY_HEALTH_UNKNOWN -> "unspecified"
    else -> null
  }
}
