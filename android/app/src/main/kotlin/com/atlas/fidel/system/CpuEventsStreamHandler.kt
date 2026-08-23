package com.atlas.fidel.system

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.io.RandomAccessFile
import java.util.concurrent.atomic.AtomicBoolean

/** 1 Hz aggregate CPU usage from /proc/stat (usageRatio + core count). */
class CpuEventsStreamHandler(private val context: Context) : EventChannel.StreamHandler {
  private val mainHandler = Handler(Looper.getMainLooper())
  private val active = AtomicBoolean(false)

  private var sink: EventChannel.EventSink? = null
  private var lastTotal: Long = 0
  private var lastIdle: Long = 0

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

  private val ticker = object : Runnable {
    override fun run() {
      if (!active.get()) return
      try {
        val stat = readProcStat()
        val diffTotal = stat.total - lastTotal
        val diffIdle = stat.idle - lastIdle
        val usage = if (diffTotal <= 0) {
          0.0
        } else {
          (diffTotal - diffIdle).toDouble() / diffTotal.toDouble()
        }

        lastTotal = stat.total
        lastIdle = stat.idle

        sink?.success(
          mapOf("usageRatio" to usage, "cores" to Runtime.getRuntime().availableProcessors())
        )
      } catch (_: Exception) {
        sink?.success(
          mapOf("usageRatio" to 0.0, "cores" to Runtime.getRuntime().availableProcessors())
        )
      }
      mainHandler.postDelayed(this, 1000)
    }
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    sink = events
    active.set(true)
    val initial = readProcStat()
    lastTotal = initial.total
    lastIdle = initial.idle
    // Native delays the first tick so the delta window is meaningful.
    mainHandler.postDelayed(ticker, 1000)
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
