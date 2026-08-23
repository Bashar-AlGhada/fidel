import 'package:flutter_test/flutter_test.dart';
import 'package:fidel/infrastructure/mappers/network_status_mapper.dart';

void main() {
  const mapper = NetworkStatusMapper();

  test('wifi details survive transport switch to cellular', () {
    // Mapper semantics: entity.metered := frame['metered'] != true, so
    // only an explicit native `metered: true` yields metered == false.
    final state = mapper.fromMap(const {
      'kind': 'state',
      'connected': true,
      'transport': 'wifi',
    });
    expect(state.transport, 'wifi');
    expect(state.connected, isTrue);
    expect(state.metered, isFalse);

    final wifi = mapper.fromMap(const {
      'kind': 'wifi',
      'rssi': -50,
      'ssid': 'Home',
    }, previous: state);
    expect(wifi.rssi, -50);
    expect(wifi.ssid, 'Home');

    final cell = mapper.fromMap(const {
      'kind': 'state',
      'connected': true,
      'metered': true,
      'transport': 'cellular',
    }, previous: wifi);
    // Transport/connected/metered updated...
    expect(cell.transport, 'cellular');
    expect(cell.connected, isTrue);
    expect(cell.metered, isTrue);
    // ...while the Wi-Fi link details carry forward.
    expect(cell.rssi, -50);
    expect(cell.ssid, 'Home');
  });

  test('ble fields are preserved across subsequent state frames', () {
    final ble = mapper.fromMap(const {
      'kind': 'ble',
      'count': 12,
      'avgRssi': -70.0,
      'strongestRssi': -52,
    });
    expect(ble.bleCount, 12);
    expect(ble.bleAvgRssi, -70.0);
    expect(ble.bleStrongestRssi, -52);

    final state = mapper.fromMap(const {
      'kind': 'state',
      'connected': true,
      'metered': false,
      'transport': 'other',
    }, previous: ble);
    // Native emits ble -> state every tick; the BLE window must stay
    // visible between frames.
    expect(state.bleCount, 12);
    expect(state.bleAvgRssi, -70.0);
    expect(state.bleStrongestRssi, -52);
  });

  test('unknown kind keeps previous entity untouched', () {
    final prev = mapper.fromMap(const {
      'kind': 'wifi',
      'rssi': -40,
      'ssid': 'Office',
    });
    expect(
      mapper.fromMap(const {'kind': 'future-kind'}, previous: prev),
      same(prev),
    );
  });

  test('unknown kind without previous yields initial state', () {
    final e = mapper.fromMap(const {'kind': 'mystery'});
    expect(e.connected, isFalse);
    expect(e.metered, isFalse);
    expect(e.transport, 'none');
  });

  test('nfc present/enabled merge across frames', () {
    final present = mapper.fromMap(const {'kind': 'nfc', 'present': true});
    expect(present.nfcPresent, isTrue);
    expect(present.nfcEnabled, isNull);

    final both = mapper.fromMap(const {
      'kind': 'nfc',
      'enabled': true,
    }, previous: present);
    expect(both.nfcPresent, isTrue);
    expect(both.nfcEnabled, isTrue);
  });
}
