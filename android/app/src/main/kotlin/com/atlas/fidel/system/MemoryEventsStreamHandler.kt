package com.atlas.fidel.system

import android.app.ActivityManager
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.atomic.AtomicBoolean

/** 1 Hz memory stream: availBytes/totalBytes from ActivityManager. */
class MemoryEventsStreamHandler(private val context: Context) : EventChannel.StreamHandler {
  private val mainHandler = Handler(Looper.getMainLooper())
  private val active = AtomicBoolean(false)

  private var sink: EventChannel.EventSink? = null
  private val ticker = object : Runnable {
    override fun run() {
      if (!active.get()) return
      try {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val mi = ActivityManager.MemoryInfo()
        am.getMemoryInfo(mi)
        sink?.success(mapOf("availBytes" to mi.availMem, "totalBytes" to mi.totalMem))
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

  /** Stops the ticker; safe to call multiple times. */
  fun stop() {
    mainHandler.removeCallbacks(ticker)
    active.set(false)
    sink = null
  }

  override fun onCancel(arguments: Any?) {
    stop()
  }
}
