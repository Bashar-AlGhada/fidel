package com.atlas.fidel.system

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.ImageFormat
import android.hardware.Sensor
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.MediaCodecList
import android.media.MediaDrm
import android.os.BatteryManager
import android.os.Build
import android.os.HardwarePropertiesManager
import android.os.PowerManager
import android.os.StatFs
import android.telephony.TelephonyManager
import android.view.WindowManager
import java.io.File
import java.util.UUID

class MetadataSnapshotProvider(private val context: Context) {
  fun deviceSnapshot(): Map<String, Any?> {
    return mapOf(
      "manufacturer" to Build.MANUFACTURER,
      "model" to Build.MODEL,
      "brand" to Build.BRAND,
      "device" to Build.DEVICE,
      "product" to Build.PRODUCT,
      "hardware" to Build.HARDWARE,
      "board" to Build.BOARD,
      "supportedAbis" to Build.SUPPORTED_ABIS.toList(),
    )
  }

  fun buildSnapshot(): Map<String, Any?> {
    return mapOf(
      "sdkInt" to Build.VERSION.SDK_INT,
      "release" to Build.VERSION.RELEASE,
      "incremental" to Build.VERSION.INCREMENTAL,
      "codename" to Build.VERSION.CODENAME,
      "securityPatch" to Build.VERSION.SECURITY_PATCH,
      "fingerprint" to Build.FINGERPRINT,
      "id" to Build.ID,
      "tags" to Build.TAGS,
      "type" to Build.TYPE,
      "time" to Build.TIME,
    )
  }

  fun displaySnapshot(): Map<String, Any?> {
    val metrics = context.resources.displayMetrics
    val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    val refreshRates = try {
      val display = if (Build.VERSION.SDK_INT >= 30) context.display else @Suppress("DEPRECATION") wm.defaultDisplay
      val modes = if (Build.VERSION.SDK_INT >= 23) display?.supportedModes else null
      when {
        modes != null -> modes.map { it.refreshRate.toDouble() }.distinct().sorted()
        display != null -> listOf(@Suppress("DEPRECATION") display.refreshRate.toDouble())
        else -> emptyList()
      }
    } catch (_: Exception) {
      emptyList<Double>()
    }

    return mapOf(
      "widthPx" to metrics.widthPixels,
      "heightPx" to metrics.heightPixels,
      "density" to metrics.density.toDouble(),
      "densityDpi" to metrics.densityDpi,
      "scaledDensity" to metrics.scaledDensity.toDouble(),
      "xdpi" to metrics.xdpi.toDouble(),
      "ydpi" to metrics.ydpi.toDouble(),
      "refreshRatesHz" to refreshRates,
    )
  }

  fun batterySnapshot(): Map<String, Any?> {
    val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
    val intent = if (Build.VERSION.SDK_INT >= 33) {
      context.registerReceiver(null, filter, Context.RECEIVER_NOT_EXPORTED)
    } else {
      @Suppress("DEPRECATION")
      context.registerReceiver(null, filter)
    }

    val bm = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
    val pctFromBm = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY).takeIf { it >= 0 }

    val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
    val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
    val pctFromIntent = if (level >= 0 && scale > 0) ((level.toDouble() / scale.toDouble()) * 100.0) else null

    val status = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
    val health = intent?.getIntExtra(BatteryManager.EXTRA_HEALTH, -1)
    val plugged = intent?.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1)
    val voltageMv = intent?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, -1)?.takeIf { it >= 0 }
    val tempTenthC = intent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1)?.takeIf { it >= 0 }
    val tempC = tempTenthC?.let { it.toDouble() / 10.0 }

    val chargeCounterUah = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER).takeIf { it > 0 }
    val currentNowUa = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW).takeIf { it != Int.MIN_VALUE && it != 0 }
    val currentAvgUa = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_AVERAGE).takeIf { it != Int.MIN_VALUE && it != 0 }
    val energyNwh = bm.getLongPropertyCompat(BatteryManager.BATTERY_PROPERTY_ENERGY_COUNTER).takeIf { it > 0 }

    return mapOf(
      "percent" to (pctFromBm ?: pctFromIntent),
      "status" to status,
      "health" to health,
      "plugged" to plugged,
      "voltageMv" to voltageMv,
      "temperatureC" to tempC,
      "chargeCounterUah" to chargeCounterUah,
      "currentNowUa" to currentNowUa,
      "currentAverageUa" to currentAvgUa,
      "energyCounterNwh" to energyNwh,
    )
  }

  fun camerasSnapshot(): Map<String, Any?> {
    val cm = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    val cameras = cm.cameraIdList.mapNotNull { cameraId ->
      try {
        val chars = cm.getCameraCharacteristics(cameraId)
        val lensFacing = chars.get(CameraCharacteristics.LENS_FACING)
        val lensFacingLabel = when (lensFacing) {
          CameraCharacteristics.LENS_FACING_FRONT -> "front"
          CameraCharacteristics.LENS_FACING_BACK -> "back"
          CameraCharacteristics.LENS_FACING_EXTERNAL -> "external"
          else -> "unknown"
        }
        val sensorOrientation = chars.get(CameraCharacteristics.SENSOR_ORIENTATION)
        val hardwareLevel = chars.get(CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL)
        val hasFlash = chars.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
        val focalLengths = chars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)?.map { it.toDouble() } ?: emptyList()
        val apertures = chars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_APERTURES)?.map { it.toDouble() } ?: emptyList()
        val physicalCameraIds = if (Build.VERSION.SDK_INT >= 28) {
          chars.physicalCameraIds.toList().sorted()
        } else {
          emptyList()
        }
        val fpsRanges = chars.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES)?.map { range ->
          mapOf("min" to range.lower, "max" to range.upper)
        } ?: emptyList()

        val outputMap = chars.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
        val formats = listOf(ImageFormat.JPEG, ImageFormat.YUV_420_888, ImageFormat.RAW_SENSOR)
        val outputs = if (outputMap != null) {
          formats.map { format ->
            val sizes = outputMap.getOutputSizes(format)?.toList().orEmpty()
              .sortedByDescending { it.width.toLong() * it.height.toLong() }
              .take(16)
              .map { size -> mapOf("w" to size.width, "h" to size.height) }
            mapOf("format" to format, "sizes" to sizes)
          }.filter { (it["sizes"] as List<*>).isNotEmpty() }
        } else {
          emptyList()
        }

        mapOf(
          "cameraId" to cameraId,
          "lensFacing" to lensFacing,
          "lensFacingString" to lensFacingLabel,
          "sensorOrientation" to sensorOrientation,
          "hardwareLevel" to hardwareLevel,
          "hasFlash" to hasFlash,
          "focalLengthsMm" to focalLengths,
          "apertures" to apertures,
          "physicalCameraIds" to physicalCameraIds,
          "fpsRanges" to fpsRanges,
          "outputs" to outputs,
        )
      } catch (_: Exception) {
        null
      }
    }

    return mapOf("cameras" to cameras)
  }

  fun securitySnapshot(): Map<String, Any?> {
    val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
    val thermalStatus = if (Build.VERSION.SDK_INT >= 29) powerManager.currentThermalStatus else null
    val widevine = widevineInfo()
    val telephony = telephonyInfo()

    return mapOf(
      "securityPatch" to Build.VERSION.SECURITY_PATCH,
      "isDeviceSecure" to isDeviceSecure(),
      "isStrongBoxAvailable" to isStrongBoxAvailable(),
      "widevine" to widevine,
      "telephony" to telephony,
      "currentThermalStatus" to thermalStatus,
    )
  }

  fun codecsSnapshot(): Map<String, Any?> {
    if (Build.VERSION.SDK_INT < 21) return mapOf("codecs" to emptyList<Map<String, Any?>>())
    val list = MediaCodecList(MediaCodecList.ALL_CODECS)
    val codecs = list.codecInfos.map { info ->
      val types = info.supportedTypes.toList()
      val typeDetails = types.mapNotNull { type ->
        try {
          val caps = info.getCapabilitiesForType(type)
          val profileLevels = caps.profileLevels?.toList().orEmpty().take(32).map { pl ->
            mapOf("profile" to pl.profile, "level" to pl.level)
          }
          val colorFormats = caps.colorFormats?.toList().orEmpty().take(32)
          mapOf(
            "mime" to type,
            "profileLevels" to profileLevels,
            "colorFormats" to colorFormats,
          )
        } catch (_: Exception) {
          null
        }
      }

      mapOf(
        "name" to info.name,
        "isEncoder" to info.isEncoder,
        "types" to typeDetails,
      )
    }

    return mapOf("codecs" to codecs)
  }

  fun memoryStorageSnapshot(): Map<String, Any?> {
    val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
    val mi = ActivityManager.MemoryInfo()
    am.getMemoryInfo(mi)

    val runtime = Runtime.getRuntime()
    val heap = mapOf(
      "maxBytes" to runtime.maxMemory(),
      "totalBytes" to runtime.totalMemory(),
      "freeBytes" to runtime.freeMemory(),
    )

    val storage = listOfNotNull(
      storageEntry("dataDir", context.dataDir),
      storageEntry("filesDir", context.filesDir),
      context.getExternalFilesDir(null)?.let { storageEntry("externalFilesDir", it) },
    )

    return mapOf(
      "ram" to mapOf(
        "totalBytes" to mi.totalMem,
        "availBytes" to mi.availMem,
        "lowMemory" to mi.lowMemory,
      ),
      "heap" to heap,
      "storage" to storage,
    )
  }

  fun cellularSimSnapshot(): Map<String, Any?> {
    val telephony = telephonyInfo()
    val tm = try {
      context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
    } catch (_: Exception) {
      null
    }

    val signalLevel = try {
      if (Build.VERSION.SDK_INT >= 28) tm?.signalStrength?.level else null
    } catch (_: SecurityException) {
      null
    } catch (_: Exception) {
      null
    }

    return mapOf(
      "telephony" to telephony,
      "signalLevel" to signalLevel,
    )
  }

  fun widiMiracastSnapshot(): Map<String, Any?> {
    val pm = context.packageManager
    val wifiDirect = pm.hasSystemFeature(PackageManager.FEATURE_WIFI_DIRECT)
    val wifiDisplayFeature = pm.hasSystemFeature("android.hardware.wifi.display")
    val castSettingsAvailable = Intent("android.settings.CAST_SETTINGS").resolveActivity(pm) != null

    return mapOf(
      "wifiDirect" to wifiDirect,
      "wifiDisplayFeature" to wifiDisplayFeature,
      "castSettingsAvailable" to castSettingsAvailable,
    )
  }

  fun bestEffortThermalTemperatures(): Map<String, Any?> {
    val batteryTempC = batterySnapshot()["temperatureC"]
    val cpuTempC = try {
      if (Build.VERSION.SDK_INT >= 24) {
        val hpm = context.getSystemService(Context.HARDWARE_PROPERTIES_SERVICE) as HardwarePropertiesManager
        val temps = hpm.getDeviceTemperatures(
          HardwarePropertiesManager.DEVICE_TEMPERATURE_CPU,
          HardwarePropertiesManager.TEMPERATURE_CURRENT,
        )
        temps.toList().takeIf { it.isNotEmpty() }?.average()
      } else null
    } catch (_: SecurityException) {
      null
    } catch (_: Exception) {
      null
    }

    return mapOf(
      "batteryTempC" to batteryTempC,
      "cpuTempC" to cpuTempC,
    )
  }

  private fun isDeviceSecure(): Boolean {
    return try {
      val km = context.getSystemService(Context.KEYGUARD_SERVICE) as android.app.KeyguardManager
      km.isDeviceSecure
    } catch (_: Exception) {
      false
    }
  }

  private fun isStrongBoxAvailable(): Boolean {
    return try {
      if (Build.VERSION.SDK_INT < 28) false else context.packageManager.hasSystemFeature("android.hardware.strongbox_keystore")
    } catch (_: Exception) {
      false
    }
  }

  private fun widevineInfo(): Map<String, Any?>? {
    return try {
      val uuid = UUID.fromString("edef8ba9-79d6-4ace-a3c8-27dcd51d21ed")
      val drm = MediaDrm(uuid)
      val securityLevel = drm.getPropertyString("securityLevel")
      val hdcpLevel = tryGetDrmProperty(drm, "hdcpLevel")
      val maxHdcpLevel = tryGetDrmProperty(drm, "maxHdcpLevel")
      drm.release()
      mapOf(
        "securityLevel" to securityLevel,
        "hdcpLevel" to hdcpLevel,
        "maxHdcpLevel" to maxHdcpLevel,
      )
    } catch (_: Exception) {
      null
    }
  }

  private fun telephonyInfo(): Map<String, Any?>? {
    return try {
      val tm = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
      val dataNetworkType = try {
        if (Build.VERSION.SDK_INT >= 24) tm.dataNetworkType else @Suppress("DEPRECATION") tm.networkType
      } catch (_: SecurityException) {
        null
      } catch (_: Exception) {
        null
      }

      val operator = try {
        tm.networkOperator
      } catch (_: SecurityException) {
        null
      } catch (_: Exception) {
        null
      }

      val mcc = operator?.takeIf { it.length >= 3 }?.substring(0, 3)
      val mnc = operator?.takeIf { it.length > 3 }?.substring(3)

      mapOf(
        "networkOperatorName" to safeString(tm.networkOperatorName),
        "simOperatorName" to safeString(tm.simOperatorName),
        "dataNetworkType" to dataNetworkType,
        "isNetworkRoaming" to tm.isNetworkRoaming,
        "phoneCount" to try {
          if (Build.VERSION.SDK_INT >= 23) tm.phoneCount else null
        } catch (_: SecurityException) {
          null
        } catch (_: Exception) {
          null
        },
        "mcc" to mcc,
        "mnc" to mnc,
      )
    } catch (_: Exception) {
      null
    }
  }

  private fun safeString(value: String?): String? {
    return value?.takeIf { it.isNotBlank() }
  }

  private fun tryGetDrmProperty(drm: MediaDrm, key: String): String? {
    return try {
      drm.getPropertyString(key)
    } catch (_: Exception) {
      null
    }
  }

  private fun BatteryManager.getLongPropertyCompat(id: Int): Long {
    return try {
      if (Build.VERSION.SDK_INT >= 21) getLongProperty(id) else 0L
    } catch (_: Exception) {
      0L
    }
  }

  private fun storageEntry(name: String, dir: File): Map<String, Any?> {
    return try {
      val stat = StatFs(dir.absolutePath)
      val total = stat.blockCountLong * stat.blockSizeLong
      val avail = stat.availableBlocksLong * stat.blockSizeLong
      mapOf(
        "name" to name,
        "path" to dir.absolutePath,
        "totalBytes" to total,
        "availBytes" to avail,
      )
    } catch (_: Exception) {
      mapOf(
        "name" to name,
        "path" to dir.absolutePath,
        "totalBytes" to null,
        "availBytes" to null,
      )
    }
  }
}
