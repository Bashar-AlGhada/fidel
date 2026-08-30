/// Live connectivity status plus the freshest Wi-Fi link details and
/// radio-environment readings.
///
/// Wi-Fi fields are null whenever the device is not on Wi-Fi or the OS
/// withholds them (missing location permission on API 29+). Cellular,
/// NFC and BLE fields are best-effort and may be null when the hardware
/// is absent or the platform withholds them.
class NetworkStatusEntity {
  const NetworkStatusEntity({
    required this.connected,
    required this.metered,
    required this.transport,
    this.rssi,
    this.linkSpeedMbps,
    this.frequencyMhz,
    this.ssid,
    this.bssid,
    this.ip,
    this.cellDbm,
    this.cellLevel,
    this.cellIsGsm,
    this.dataConnected,
    this.roaming,
    this.networkType,
    this.nfcPresent,
    this.nfcEnabled,
    this.bleCount,
    this.bleAvgRssi,
    this.bleStrongestRssi,
  });

  final bool connected;
  final bool metered;
  final String transport; // wifi | cellular | ethernet | vpn | other | none

  final int? rssi;
  final int? linkSpeedMbps;
  final int? frequencyMhz;
  final String? ssid;
  final String? bssid;
  final String? ip;

  final int? cellDbm;
  final int? cellLevel; // 0..4 per SignalStrength.level
  final bool? cellIsGsm;
  final bool? dataConnected;
  final bool? roaming;
  final String? networkType; // LTE | 5G | 3G | 2G

  final bool? nfcPresent;
  final bool? nfcEnabled;

  final int? bleCount;
  final double? bleAvgRssi;
  final int? bleStrongestRssi;

  bool get onWifi => transport == 'wifi';

  /// Live BLE heartbeat reporting zero devices: resets the whole BLE
  /// window so a running scan shows "scanning, 0 found" instead of
  /// carrying stale link stats forward. [copyWith] cannot write nulls,
  /// which is why this exists as an explicit reset.
  NetworkStatusEntity clearBle() {
    return NetworkStatusEntity(
      connected: connected,
      metered: metered,
      transport: transport,
      rssi: rssi,
      linkSpeedMbps: linkSpeedMbps,
      frequencyMhz: frequencyMhz,
      ssid: ssid,
      bssid: bssid,
      ip: ip,
      cellDbm: cellDbm,
      cellLevel: cellLevel,
      cellIsGsm: cellIsGsm,
      dataConnected: dataConnected,
      roaming: roaming,
      networkType: networkType,
      nfcPresent: nfcPresent,
      nfcEnabled: nfcEnabled,
      bleCount: 0,
    );
  }

  /// Null-tolerant merge helper for the radio-feed mapper: every field
  /// falls back to the current value when the argument is null.
  NetworkStatusEntity copyWith({
    bool? connected,
    bool? metered,
    String? transport,
    int? rssi,
    int? linkSpeedMbps,
    int? frequencyMhz,
    String? ssid,
    String? bssid,
    String? ip,
    int? cellDbm,
    int? cellLevel,
    bool? cellIsGsm,
    bool? dataConnected,
    bool? roaming,
    String? networkType,
    bool? nfcPresent,
    bool? nfcEnabled,
    int? bleCount,
    double? bleAvgRssi,
    int? bleStrongestRssi,
  }) {
    return NetworkStatusEntity(
      connected: connected ?? this.connected,
      metered: metered ?? this.metered,
      transport: transport ?? this.transport,
      rssi: rssi ?? this.rssi,
      linkSpeedMbps: linkSpeedMbps ?? this.linkSpeedMbps,
      frequencyMhz: frequencyMhz ?? this.frequencyMhz,
      ssid: ssid ?? this.ssid,
      bssid: bssid ?? this.bssid,
      ip: ip ?? this.ip,
      cellDbm: cellDbm ?? this.cellDbm,
      cellLevel: cellLevel ?? this.cellLevel,
      cellIsGsm: cellIsGsm ?? this.cellIsGsm,
      dataConnected: dataConnected ?? this.dataConnected,
      roaming: roaming ?? this.roaming,
      networkType: networkType ?? this.networkType,
      nfcPresent: nfcPresent ?? this.nfcPresent,
      nfcEnabled: nfcEnabled ?? this.nfcEnabled,
      bleCount: bleCount ?? this.bleCount,
      bleAvgRssi: bleAvgRssi ?? this.bleAvgRssi,
      bleStrongestRssi: bleStrongestRssi ?? this.bleStrongestRssi,
    );
  }
}
