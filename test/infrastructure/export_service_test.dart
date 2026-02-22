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
