import '../../domain/entities/testers/network_status_entity.dart';

/// Pure mapper for the native network feed's event kinds (`state`, `wifi`,
/// `cell`, `cellstate`, `nfc`, `ble`).
///
/// Callers thread [previous] through so per-radio details persist across
/// frames that do not carry them; every branch below merges via the
/// entity's null-tolerant [NetworkStatusEntity.copyWith].
class NetworkStatusMapper {
  const NetworkStatusMapper();

  /// Unknown kinds keep the previous entity untouched, mirroring how the
  /// native feed is expected to evolve additively.
  NetworkStatusEntity fromMap(
    Map<String, dynamic> map, {
    NetworkStatusEntity? previous,
  }) {
    return switch (map['kind']) {
      'wifi' => _fromWifi(map, previous),
      'cell' => _fromCell(map, previous),
      'cellstate' => _fromCellState(map, previous),
      'nfc' => _fromNfc(map, previous),
      'ble' => _fromBle(map, previous),
      'state' => _fromState(map, previous),
      _ => previous ?? _initial,
    };
  }

  NetworkStatusEntity get _initial => const NetworkStatusEntity(
    connected: false,
    metered: false,
    transport: 'none',
  );

  NetworkStatusEntity _fromState(
    Map<String, dynamic> map,
    NetworkStatusEntity? p,
  ) {
    return (p ?? _initial).copyWith(
      connected: map['connected'] == true,
      // Native sends metered:true for capped networks; keep polarity.
      metered: map['metered'] == true,
      transport: map['transport'] is String
          ? map['transport'] as String
          : 'none',
      // Native emits ble -> state every tick; carrying the window
      // forward here keeps BLE stats visible between frames.
    );
  }

  NetworkStatusEntity _fromWifi(
    Map<String, dynamic> map,
    NetworkStatusEntity? p,
  ) {
    final base = (p != null && p.onWifi)
        ? p
        : (p ?? _initial).copyWith(transport: 'wifi');
    return base.copyWith(
      connected: true,
      transport: 'wifi',
      rssi: _intOrNull(map['rssi']),
      linkSpeedMbps: _intOrNull(map['linkSpeedMbps']),
      frequencyMhz: _intOrNull(map['frequencyMhz']),
      ssid: _stringOrNull(map['ssid']),
      bssid: _stringOrNull(map['bssid']),
      ip: _stringOrNull(map['ip']),
    );
  }

  NetworkStatusEntity _fromCell(
    Map<String, dynamic> map,
    NetworkStatusEntity? p,
  ) {
    return (p ?? _initial).copyWith(
      cellDbm: _intOrNull(map['dbm']),
      cellLevel: _intOrNull(map['level']),
      cellIsGsm: map['isGsm'] is bool ? map['isGsm'] as bool : null,
    );
  }

  NetworkStatusEntity _fromCellState(
    Map<String, dynamic> map,
    NetworkStatusEntity? p,
  ) {
    return (p ?? _initial).copyWith(
      dataConnected: map['dataConnected'] is bool
          ? map['dataConnected'] as bool
          : null,
      roaming: map['roaming'] is bool ? map['roaming'] as bool : null,
      networkType: _stringOrNull(map['networkTypeName']),
    );
  }

  NetworkStatusEntity _fromNfc(
    Map<String, dynamic> map,
    NetworkStatusEntity? p,
  ) {
    return (p ?? _initial).copyWith(
      nfcPresent: map['present'] is bool ? map['present'] as bool : null,
      nfcEnabled: map['enabled'] is bool ? map['enabled'] as bool : null,
    );
  }

  NetworkStatusEntity _fromBle(
    Map<String, dynamic> map,
    NetworkStatusEntity? p,
  ) {
    final base = p ?? _initial;
    final count = _intOrNull(map['count']);
    // A live heartbeat with an explicit zero count must clear the stale
    // link stats (copyWith cannot write nulls), otherwise the UI keeps
    // showing devices that are no longer in range.
    if (count == 0) return base.clearBle();
    return base.copyWith(
      bleCount: count,
      bleAvgRssi: map['avgRssi'] is num
          ? (map['avgRssi'] as num).toDouble()
          : null,
      bleStrongestRssi: _intOrNull(map['strongestRssi']),
    );
  }

  int? _intOrNull(Object? raw) =>
      raw is int ? raw : (raw is num ? raw.toInt() : null);

  String? _stringOrNull(Object? raw) =>
      raw is String && raw.isNotEmpty ? raw : null;
}
