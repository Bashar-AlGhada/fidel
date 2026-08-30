package com.atlas.fidel.system

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

/**
 * 1 Hz CPU usage from /proc/stat:
 *
 * ```
 * { "usageRatio": 0.37,               // aggregate, 0..1
 *   "cores": 8,                       // Runtime.getRuntime().availableProcessors()
 *   "coreUsages": [0.02, ...],        // size == cores, values 0..1
 *   "coreFreqsMhz": [1804.8, null] }  // size == cores, MHz; null when unavailable
 * ```
 *
 * Aggregate and per-core counters are seeded on listen so the first emitted
 * delta window is meaningful. An unreadable or unparseable /proc/stat emits
 * a `kind:"error"` frame (`proc_stat_unreadable`) instead of a fake 0%
 * sample; individual core quirks degrade to 0.0/default values, never errors.
 */
class CpuEventsStreamHandler(private val context: Context) : EventChannel.StreamHandler {
  private val mainHandler = Handler(Looper.getMainLooper())
  private val active = AtomicBoolean(false)
  private val whitespace = Regex("\\s+")

  private var sink: EventChannel.EventSink? = null
  private var lastTotal: Long = 0
  private var lastIdle: Long = 0
  private val lastCoreTotals = mutableMapOf<Int, CpuStat>()

  private data class CpuStat(val total: Long, val idle: Long)

  private data class ProcStat(val aggregate: CpuStat, val cores: Map<Int, CpuStat>)

  /**
   * Total = user+nice+system+idle+iowait+irq+softirq+steal; guest/guest_nice
   * already fold into user/nice upstream, so summing them double-counts.
   */
  private fun parseCpuLine(parts: List<String>): CpuStat? {
    if (parts.size < 8) return null
    fun field(index: Int): Long = parts.getOrNull(index)?.toLongOrNull() ?: 0
    val idle = field(4)
    val iowait = field(5)
    val total = field(1) + field(2) + field(3) + idle + iowait + field(6) + field(7) + field(8)
    return CpuStat(total = total, idle = idle + iowait)
  }

  /** Parses the aggregate `cpu` line plus every per-core `cpuN` line. */
  private fun readProcStat(): ProcStat {
    var aggregate: CpuStat? = null
    val cores = mutableMapOf<Int, CpuStat>()
    File("/proc/stat").useLines { lines ->
      for (raw in lines) {
        if (!raw.startsWith("cpu")) continue
        val parts = raw.split(whitespace).filter { it.isNotBlank() }
        val label = parts.firstOrNull() ?: continue
        if (label == "cpu") {
          aggregate = parseCpuLine(parts) ?: aggregate
        } else {
          val index = label.removePrefix("cpu").toIntOrNull() ?: continue
          parseCpuLine(parts)?.let { cores[index] = it }
        }
      }
    }
    return ProcStat(
      aggregate = aggregate ?: throw IllegalStateException("proc_stat_unreadable"),
      cores = cores,
    )
  }

  /** Current frequency in MHz, or null for offline/unreadable cores. */
  private fun coreFrequencyMhz(coreIndex: Int): Double? {
    val dir = "/sys/devices/system/cpu/cpu$coreIndex/cpufreq"
    for (node in listOf("scaling_cur_freq", "cpuinfo_cur_freq")) {
      try {
        val khz = File("$dir/$node").readText().trim().toDoubleOrNull() ?: continue
        if (khz > 0) return khz / 1000.0
      } catch (_: Exception) {
        // Missing nodes are normal (offline cores, OEM quirks); fall through.
      }
    }
    return null
  }

  /** Delta-window usage between [prevTotal]/[prevIdle] and [stat], clamped 0..1. */
  private fun usage(prevTotal: Long, prevIdle: Long, stat: CpuStat): Double {
    val diffTotal = stat.total - prevTotal
    val diffIdle = stat.idle - prevIdle
    if (diffTotal <= 0) return 0.0
    return ((diffTotal - diffIdle).toDouble() / diffTotal.toDouble()).coerceIn(0.0, 1.0)
  }

  private val ticker = object : Runnable {
    override fun run() {
      if (!active.get()) return

      val stat = try {
        readProcStat()
      } catch (e: Exception) {
        // Deliberately not masked as a valid 0% sample; see [emitErrorTo].
        emitErrorTo(sink, "proc_stat_unreadable", e.message)
        stop()
        return
      }

      val coreCount = Runtime.getRuntime().availableProcessors()
      val aggregateUsage = usage(lastTotal, lastIdle, stat.aggregate)
      lastTotal = stat.aggregate.total
      lastIdle = stat.aggregate.idle

      val coreUsages = MutableList(coreCount) { 0.0 }
      for ((index, coreStat) in stat.cores) {
        if (index !in coreUsages.indices) continue
        val prev = lastCoreTotals[index]
        coreUsages[index] =
          if (prev == null) 0.0 else usage(prev.total, prev.idle, coreStat)
      }
      lastCoreTotals.clear()
      lastCoreTotals.putAll(stat.cores)

      val coreFreqsMhz = List(coreCount) { coreIndex -> coreFrequencyMhz(coreIndex) }

      sink?.success(
        mapOf(
          "usageRatio" to aggregateUsage,
          "cores" to coreCount,
          "coreUsages" to coreUsages,
          "coreFreqsMhz" to coreFreqsMhz,
        )
      )
      mainHandler.postDelayed(this, 1000)
    }
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    sink = events
    active.set(true)
    try {
      val initial = readProcStat()
      lastTotal = initial.aggregate.total
      lastIdle = initial.aggregate.idle
      lastCoreTotals.clear()
      lastCoreTotals.putAll(initial.cores)
    } catch (_: Exception) {
      // Seeding is best-effort; the first tick reports the real failure.
    }
    // Native delays the first tick so the delta window is meaningful.
    mainHandler.postDelayed(ticker, 1000)
  }

  // Delivers through an explicit sink so the failure still reaches Dart
  // even when [stop] has already cleared the field.
  private fun emitErrorTo(target: EventChannel.EventSink?, code: String, message: String?) {
    mainHandler.post {
      target?.success(mapOf("kind" to "error", "code" to code, "message" to (message ?: "")))
    }
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
