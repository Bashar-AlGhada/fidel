package com.atlas.fidel.system

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.Manifest
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import com.atlas.fidel.BuildConfig
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.nfc.NfcAdapter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.PhoneStateListener
import android.telephony.SignalStrength
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import io.flutter.plugin.common.EventChannel
import java.net.Inet4Address
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Streams connectivity state, Wi-Fi link details, cellular signal, NFC and
 * Bluetooth-LE radio environment:
 *
 * ```
 * { "kind": "state", "connected": true, "metered": false, "transport": "wifi" }
 * { "kind": "wifi",  "rssi": -47, ... }
 * { "kind": "cell",  "subscriptionId": 1, "dbm": -97, "level": 3,
 *   "isGsm": true, "dataConnected": true, "roaming": false }
 * { "kind": "nfc",   "present": true, "enabled": false }
 * { "kind": "ble",   "count": 12, "avgRssi": -78, "strongestRssi": -52 }
 * ```
 *
 * `ssid`/`ip`/`bssid` degrade to null without the required permissions;
 * BLE results are aggregated statistics only (no MACs/names leave the
 * device).
 *
 * Unlike the GNSS/noise handlers this feed never emits `kind:"error"`
 * frames; internal failures are swallowed here and simply surface as
 * absent fields downstream.
 */
class NetworkEventsStreamHandler(private val context: Context) : EventChannel.StreamHandler {
  private val mainHandler = Handler(Looper.getMainLooper())
  private val active = AtomicBoolean(false)

  private var sink: EventChannel.EventSink? = null
  private var connectivityManager: ConnectivityManager? = null
  private var bluetoothLeScanner: BluetoothLeScanner? = null

  // BLE aggregation window.
  private val bleRssis = mutableListOf<Int>()
  private val bleScanning = AtomicBoolean(false)

  private val bleCallback = object : ScanCallback() {
    override fun onScanResult(callbackType: Int, result: ScanResult) {
      synchronized(bleRssis) { bleRssis.add(result.rssi) }
    }
  }

  private val phoneListeners = mutableListOf<Pair<PhoneStateListener, TelephonyManager>>()

  private companion object {
    const val pollInitialDelayMs = 250L
    const val pollIntervalMs = 1000L
  }

  private val ticker = object : Runnable {
    override fun run() {
      if (!active.get()) return
      try {
        emitWifiInfo()
        emitCellSnapshot()
        emitNfc()
        emitBleWindow()
        emitState()
      } catch (e: Exception) {
        // OEM connectivity/NFC APIs vary wildly; a single bad call must
        // never take down the main thread or kill the poll loop.
        if (BuildConfig.DEBUG) {
          android.util.Log.w("fidel_network", "poll failed", e)
        }
      }
      mainHandler.postDelayed(this, pollIntervalMs)
    }
  }

  private val networkCallback = object : ConnectivityManager.NetworkCallback() {
    override fun onAvailable(network: Network) = emitState()
    override fun onLost(network: Network) = emitState()
    override fun onCapabilitiesChanged(
      network: Network,
      capabilities: NetworkCapabilities,
    ) = emitState()
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    stop()

    sink = events
    active.set(true)

    connectivityManager =
      context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    try {
      connectivityManager?.registerDefaultNetworkCallback(networkCallback)
    } catch (_: Exception) {
      Unit
    }

    registerCellListeners()

    // Initial stagger lets the first network callback land before the
    // first poll so state details are populated on arrival.
    mainHandler.postDelayed(ticker, pollInitialDelayMs)
  }

  override fun onCancel(arguments: Any?) {
    stop()
  }

  fun stop() {
    // Cancel pending polls before flipping `active`; a surviving post
    // would otherwise outlive its guard on a rapid re-listen.
    mainHandler.removeCallbacks(ticker)
    sink = null
    if (!active.getAndSet(false)) return

    setBleScanning(false)
    try {
      connectivityManager?.unregisterNetworkCallback(networkCallback)
    } catch (_: Exception) {
      Unit
    }
    connectivityManager = null

    for ((listener, tm) in phoneListeners) {
      try {
        tm.listen(listener, PhoneStateListener.LISTEN_NONE)
      } catch (_: Exception) {
        Unit
      }
    }
    phoneListeners.clear()
  }

  /** Flutter toggles the privacy-safe aggregate BLE scan from the UI. */
  @SuppressLint("MissingPermission") // Caller gates on BLUETOOTH_SCAN; re-checked below for defense in depth.
  fun setBleScanning(enabled: Boolean) {
    if (enabled == bleScanning.get()) return

    if (!enabled) {
      bleScanning.set(false)
      synchronized(bleRssis) { bleRssis.clear() }
      try {
        bluetoothLeScanner?.stopScan(bleCallback)
      } catch (_: Exception) {
        Unit
      }
      bluetoothLeScanner = null
      return
    }

    val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager ?: return
    val adapter = try {
      manager.adapter?.takeIf { it.isEnabled }
    } catch (_: SecurityException) {
      null // BLUETOOTH_CONNECT not granted yet.
    } ?: return
    val hasPermission = if (android.os.Build.VERSION.SDK_INT >= 31) {
      context.checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) ==
        PackageManager.PERMISSION_GRANTED
    } else {
      context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
        PackageManager.PERMISSION_GRANTED
    }
    if (!hasPermission) return

    val scanner = adapter.bluetoothLeScanner ?: return
    val settings = ScanSettings.Builder()
      .setScanMode(ScanSettings.SCAN_MODE_LOW_POWER)
      .build()
    try {
      scanner.startScan(null, settings, bleCallback)
      bluetoothLeScanner = scanner
      bleScanning.set(true)
    } catch (_: Exception) {
      Unit
    }
  }

  private fun emitBleWindow() {
    if (!bleScanning.get()) return
    val snapshot = synchronized(bleRssis) {
      val copy = bleRssis.toList()
      bleRssis.clear()
      copy
    }
    if (snapshot.isEmpty()) return

    mainHandler.post {
      sink?.success(
        mapOf(
          "kind" to "ble",
          "count" to snapshot.size,
          "avgRssi" to snapshot.average(),
          "strongestRssi" to snapshot.max(),
        )
      )
    }
  }

  private fun registerCellListeners() {
    val sm = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE)
      as? SubscriptionManager ?: return

    @Suppress("DEPRECATION")
    fun wire(subscriptionId: Int) {
      val tm = (context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager)
        .createForSubscriptionId(subscriptionId)
      val listener = object : PhoneStateListener() {
        override fun onSignalStrengthsChanged(signalStrength: SignalStrength?) {
          if (signalStrength != null) emitCell(subscriptionId, signalStrength)
        }
      }
      try {
        tm.listen(listener, PhoneStateListener.LISTEN_SIGNAL_STRENGTHS)
        phoneListeners.add(listener to tm)
      } catch (_: Exception) {
        Unit
      }
    }

    val subs = try {
      sm.activeSubscriptionInfoList
    } catch (_: SecurityException) {
      null
    } ?: emptyList()
    for (sub in subs) wire(sub.subscriptionId)
  }

  @Suppress("DEPRECATION")
  private fun emitCell(subscriptionId: Int, strength: SignalStrength) {
    mainHandler.post {
      sink?.success(
        mapOf(
          "kind" to "cell",
          // Multi-SIM note: frames from every subscription feed one merged
          // Dart-side entity; the strongest/last update wins per field.
          "dbm" to strength.dbm,
          "level" to strength.level,
          "isGsm" to strength.isGsm,
        )
      )
    }
  }

  private fun emitCellSnapshot() {
    val tm = context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager ?: return
    val dataConnected = try {
      tm.isDataEnabled && tm.dataState == TelephonyManager.DATA_CONNECTED
    } catch (_: Exception) {
      false
    }
    mainHandler.post {
      sink?.success(
        mapOf(
          "kind" to "cellstate",
          "dataConnected" to dataConnected,
          "roaming" to try {
            tm.isNetworkRoaming
          } catch (_: Exception) {
            false
          },
          "networkTypeName" to try {
            @Suppress("DEPRECATION")
            tm.networkType.let { networkTypeName(it) }
          } catch (_: Exception) {
            null
          },
        )
      )
    }
  }

  private fun networkTypeName(type: Int): String = when (type) {
    TelephonyManager.NETWORK_TYPE_GPRS, TelephonyManager.NETWORK_TYPE_EDGE -> "2G"
    TelephonyManager.NETWORK_TYPE_UMTS,
    TelephonyManager.NETWORK_TYPE_HSDPA,
    TelephonyManager.NETWORK_TYPE_HSUPA,
    TelephonyManager.NETWORK_TYPE_HSPA,
    -> "3G"
    TelephonyManager.NETWORK_TYPE_LTE -> "LTE"
    TelephonyManager.NETWORK_TYPE_NR -> "5G"
    else -> "?"
  }

  private fun emitNfc() {
    val hasNfc = context.packageManager.hasSystemFeature(PackageManager.FEATURE_NFC)
    val adapter = if (hasNfc) NfcAdapter.getDefaultAdapter(context) else null
    mainHandler.post {
      sink?.success(mapOf("kind" to "nfc", "present" to (adapter != null), "enabled" to (adapter?.isEnabled == true)))
    }
  }

  private fun emitState() {
    val cm = connectivityManager ?: return
    val network = cm.activeNetwork
    val caps = network?.let { cm.getNetworkCapabilities(it) }

    val transport = when {
      caps == null -> "none"
      caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN) -> "vpn"
      caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
      caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
      caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
      else -> "other"
    }

    mainHandler.post {
      sink?.success(
        mapOf(
          "kind" to "state",
          "connected" to (caps != null && caps.hasCapability(
            NetworkCapabilities.NET_CAPABILITY_VALIDATED
          )),
          "metered" to (caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) == false),
          "transport" to transport,
        )
      )
    }
  }

  private fun emitWifiInfo() {
    val cm = connectivityManager ?: return
    val caps = cm.activeNetwork?.let { cm.getNetworkCapabilities(it) }
    if (caps == null || !caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) return

    val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE)
      as? WifiManager ?: return
    val info = wifiManager.connectionInfo ?: return

    mainHandler.post {
      sink?.success(
        mapOf(
          "kind" to "wifi",
          "rssi" to info.rssi,
          "linkSpeedMbps" to info.linkSpeed,
          "frequencyMhz" to info.frequency,
          "ssid" to normalizeSsid(info.ssid),
          "bssid" to normalizeBssid(info.bssid),
          "ip" to ipv4Address(),
        )
      )
    }
  }

  private fun normalizeSsid(raw: String?): String? {
    val stripped = raw?.removePrefix("\"")?.removeSuffix("\"")?.trim()
    return if (stripped.isNullOrEmpty() || stripped == "<unknown ssid>") null else stripped
  }

  private fun normalizeBssid(raw: String?): String? =
    raw?.takeIf { it.isNotBlank() && it != "02:00:00:00:00:00" }

  private fun ipv4Address(): String? {
    val cm = connectivityManager ?: return null
    val network = cm.activeNetwork ?: return null
    val props = try {
      cm.getLinkProperties(network)
    } catch (_: Exception) {
      null
    } ?: return null
    return props.linkAddresses
      .mapNotNull { it.address as? Inet4Address }
      .firstOrNull()?.hostAddress
  }
}

