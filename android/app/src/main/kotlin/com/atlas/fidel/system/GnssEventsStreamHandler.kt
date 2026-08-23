package com.atlas.fidel.system

import android.annotation.SuppressLint
import android.content.Context
import android.location.GnssStatus
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.Process
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Streams GNSS fixes (~1 Hz) and satellite visibility:
 *
 * ```
 * { "kind": "fix", "latitude": .., "longitude": .., "altitudeM": ..,
 *   "speedMps": .., "accuracyM": .., "bearingDeg": .. }
 * { "kind": "satellites", "total": 31, "used": 9 }
 * ```
 */
class GnssEventsStreamHandler(private val context: Context) : EventChannel.StreamHandler {
  private val mainHandler = Handler(Looper.getMainLooper())
  private val active = AtomicBoolean(false)

  private var sink: EventChannel.EventSink? = null
  private var locationManager: LocationManager? = null
  private var handlerThread: HandlerThread? = null

  private val locationListener = LocationListener { location ->
    emitFix(location)
  }

  private val gnssCallback = object : GnssStatus.Callback() {
    override fun onSatelliteStatusChanged(status: GnssStatus) {
      var used = 0
      for (i in 0 until status.satelliteCount) {
        if (status.usedInFix(i)) used++
      }
      mainHandler.post {
        sink?.success(
          mapOf("kind" to "satellites", "total" to status.satelliteCount, "used" to used)
        )
      }
    }
  }

  @SuppressLint("MissingPermission") // Flutter side gates on fine location.
  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    stop()

    sink = events
    active.set(true)

    val lm = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    locationManager = lm

    if (!lm.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
      emitErrorTo(events, "gps_disabled", "GPS provider is disabled.")
    }

    try {
      handlerThread = HandlerThread("fidel_gnss", Process.THREAD_PRIORITY_BACKGROUND)
        .also { it.start() }
      val looper = handlerThread!!.looper

      lm.requestLocationUpdates(
        LocationManager.GPS_PROVIDER,
        1_000L,
        0f,
        locationListener,
        looper,
      )
      lm.registerGnssStatusCallback(gnssCallback, Handler(looper))
    } catch (e: SecurityException) {
      emitErrorTo(events, "permission_denied", e.message)
      stop()
    } catch (e: Exception) {
      emitErrorTo(events, "gnss_init_failed", e.message)
      stop()
    }
  }

  override fun onCancel(arguments: Any?) {
    stop()
  }

  fun stop() {
    sink = null
    if (!active.getAndSet(false)) return

    try {
      locationManager?.removeUpdates(locationListener)
    } catch (_: Exception) {
      Unit
    }
    try {
      locationManager?.unregisterGnssStatusCallback(gnssCallback)
    } catch (_: Exception) {
      Unit
    }
    locationManager = null

    try {
      handlerThread?.quitSafely()
    } catch (_: Exception) {
      Unit
    }
    handlerThread = null
  }

  private fun emitFix(location: Location) {
    // Satellite counts travel on their own "satellites" frames; the Dart
    // repository merges them into fixes, keeping this emitter stateless.
    mainHandler.post {
      sink?.success(
        mapOf(
          "kind" to "fix",
          "latitude" to location.latitude,
          "longitude" to location.longitude,
          "altitudeM" to if (location.hasAltitude()) location.altitude else null,
          "speedMps" to if (location.hasSpeed()) location.speed.toDouble() else null,
          "accuracyM" to if (location.hasAccuracy()) location.accuracy.toDouble() else null,
          "bearingDeg" to if (location.hasBearing()) location.bearing.toDouble() else null,
        )
      )
    }
  }

  // Delivers through an explicit sink so init failures still reach Dart
  /// even when [stop] has already cleared the field.
  private fun emitErrorTo(
    target: EventChannel.EventSink?,
    code: String,
    message: String?,
  ) {
    mainHandler.post {
      target?.success(mapOf("kind" to "error", "code" to code, "message" to (message ?: "")))
    }
  }
}

