package com.atlas.fidel.system

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.Process
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.log10
import kotlin.math.sqrt

/**
 * Streams microphone input as a live noise level. Emits roughly every
 * [emitIntervalMs] a payload of:
 *
 * ```
 * {
 *   "kind": "level",
 *   "dbfs": -34.2,   // raw digital level, 0 = clipping
 *   "spl":  55.8,    // rough SPL estimate (uncalibrated +100 dB offset)
 *   "peakDbfs": -21.0,
 * }
 * ```
 */
class NoiseEventsStreamHandler : EventChannel.StreamHandler {
  private companion object {
    const val emitIntervalMs = 50L
  }

  private val mainHandler = Handler(Looper.getMainLooper())
  private val active = AtomicBoolean(false)

  private var sink: EventChannel.EventSink? = null
  private var handlerThread: HandlerThread? = null
  private var audioRecord: AudioRecord? = null

  @SuppressLint("MissingPermission") // Flutter side gates on RECORD_AUDIO.
  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    stop()

    sink = events

    val sampleRateHz = 44_100
    val minBufferBytes = AudioRecord.getMinBufferSize(
      sampleRateHz,
      AudioFormat.CHANNEL_IN_MONO,
      AudioFormat.ENCODING_PCM_16BIT,
    )
    if (minBufferBytes <= 0) {
      emitError("audio_init_failed", "Invalid minimum buffer size.")
      return
    }

    val record = try {
      AudioRecord(
        MediaRecorder.AudioSource.MIC,
        sampleRateHz,
        AudioFormat.CHANNEL_IN_MONO,
        AudioFormat.ENCODING_PCM_16BIT,
        maxOf(minBufferBytes, sampleRateHz), // >= 1s of headroom
      )
    } catch (e: Exception) {
      emitError("audio_init_failed", e.message)
      return
    }

    if (record.state != AudioRecord.STATE_INITIALIZED) {
      record.release()
      emitError("audio_init_failed", "AudioRecord not initialized.")
      return
    }

    active.set(true)
    audioRecord = record

    // Without this the buffer never fills and the feed emits nothing.
    record.startRecording()

    val readThread = HandlerThread("fidel_noise", Process.THREAD_PRIORITY_BACKGROUND)
      .also { it.start() }
    handlerThread = readThread
    val readHandler = Handler(readThread.looper)
    val readBuffer = ShortArray(sampleRateHz / 10) // 100 ms windows

    readHandler.post(object : Runnable {
      override fun run() {
        if (!active.get()) return

        val count = try {
          record.read(readBuffer, 0, readBuffer.size)
        } catch (_: Exception) {
          -1
        }
        if (!active.get()) return

        if (count > 0) {
          var sumSquares = 0L
          var peak = 0
          for (i in 0 until count) {
            val v = readBuffer[i].toInt()
            sumSquares += v.toLong() * v.toLong()
            val abs = if (v < 0) -v else v
            if (abs > peak) peak = abs
          }
          val rms = sqrt(sumSquares.toDouble() / count.toDouble())
          // Guard log10(0); full-scale short is 32768.
          val dbfs = if (rms <= 0.0) -120.0 else 20.0 * log10(rms / 32768.0)
          val peakDbfs = if (peak <= 0) -120.0 else 20.0 * log10(peak / 32768.0)

          mainHandler.post {
            sink?.success(
              mapOf(
                "kind" to "level",
                "dbfs" to dbfs.coerceAtLeast(-120.0),
                "spl" to (dbfs + 100.0).coerceIn(0.0, 130.0),
                "peakDbfs" to peakDbfs.coerceAtLeast(-120.0),
              )
            )
          }
        }

        readHandler.postDelayed(this, emitIntervalMs)
      }
    })
  }

  override fun onCancel(arguments: Any?) {
    stop()
  }

  fun stop() {
    sink = null
    if (!active.getAndSet(false)) return

    try {
      audioRecord?.stop()
    } catch (_: Exception) {
      Unit
    }
    try {
      audioRecord?.release()
    } catch (_: Exception) {
      Unit
    }
    audioRecord = null

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
  }

  private fun emitError(code: String, message: String?) {
    mainHandler.post {
      sink?.success(
        mapOf(
          "kind" to "error",
          "code" to code,
          "message" to (message ?: ""),
        )
      )
    }
  }
}
