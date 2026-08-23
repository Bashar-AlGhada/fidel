import 'package:flutter_test/flutter_test.dart';
import 'package:fidel/infrastructure/export/export_service.dart';

void main() {
  test('sanitizeForExport redacts sensitive keys recursively', () {
    final input = <String, dynamic>{
      'device': <String, dynamic>{
        'androidId': 'abc',
        'serial': 'xyz',
        'ok': true,
      },
      'wifi': <String, dynamic>{'ssid': 'Home', 'bssid': '11:22:33:44:55:66'},
      'build': <String, dynamic>{'fingerprint': 'fp'},
      'list': [
        {'imei': '123'},
        {'value': 1},
      ],
    };

    final sanitized =
        ExportService.sanitizeForExport(input) as Map<String, dynamic>;
    expect((sanitized['device'] as Map)['androidId'], '<redacted>');
    expect((sanitized['device'] as Map)['serial'], '<redacted>');
    expect((sanitized['device'] as Map)['ok'], true);
    expect((sanitized['wifi'] as Map)['ssid'], '<redacted>');
    expect((sanitized['wifi'] as Map)['bssid'], '<redacted>');
    expect((sanitized['build'] as Map)['fingerprint'], '<redacted>');
    expect(((sanitized['list'] as List)[0] as Map)['imei'], '<redacted>');
    expect(((sanitized['list'] as List)[1] as Map)['value'], 1);
  });

  test('sanitizeForExport redacts mac-style keys at any depth', () {
    final input = <String, dynamic>{
      'radios': [
        {'mac': 'AA:BB:CC:DD:EE:FF'},
        [
          {'meid': '99', 'keep': 'visible'},
        ],
      ],
    };

    final sanitized =
        ExportService.sanitizeForExport(input) as Map<String, dynamic>;
    final radios = sanitized['radios'] as List;
    expect((radios[0] as Map)['mac'], '<redacted>');
    expect(((radios[1] as List)[0] as Map)['meid'], '<redacted>');
    expect(((radios[1] as List)[0] as Map)['keep'], 'visible');
  });

  test('sanitizeForExport turns non-finite doubles into null', () {
    // JSON has no NaN/Infinity representation; these must not leak.
    final sanitized =
        ExportService.sanitizeForExport(<String, dynamic>{
              'a': double.nan,
              'b': double.infinity,
              'c': double.negativeInfinity,
              'd': [double.nan, 1.5],
              'e': 42,
            })
            as Map<String, dynamic>;

    expect(sanitized['a'], isNull);
    expect(sanitized['b'], isNull);
    expect(sanitized['c'], isNull);
    expect(sanitized['d'], [null, 1.5]);
    expect(sanitized['e'], 42);
  });

  test('csvEncode quotes cells with commas, quotes, or newlines', () {
    final csv = ExportService.csvEncode([
      ['a', 'b'],
      ['x,y', 'hello'],
      ['quote', 'a"b'],
      ['multi', 'line1\nline2'],
    ]);

    expect(csv, contains('"x,y"'));
    expect(csv, contains('"a""b"'));
    expect(csv, contains('"line1\nline2"'));
  });
}
