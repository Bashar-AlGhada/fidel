import 'package:flutter_test/flutter_test.dart';

import 'package:fidel/infrastructure/mappers/sensor_event_mapper.dart';

void main() {
  test('capabilityFromMap parses numeric fields', () {
    final mapper = SensorEventMapper();

    final cap = mapper.capabilityFromMap({
      'key': '1:Foo:Bar',
      'name': 'Foo',
      'vendor': 'Bar',
      'type': 1,
      'maxRange': 10.5,
      'resolution': 0.1,
      'powerMilliAmp': 0.2,
      'minDelayUs': 20000,
    });

    expect(cap, isNotNull);
    expect(cap!.key, '1:Foo:Bar');
    expect(cap.minDelay.inMicroseconds, 20000);
    expect(cap.maxRange, 10.5);
  });

  test('readingFromMap maps timestamp and values', () {
    final mapper = SensorEventMapper();

    final reading = mapper.readingFromMap({
      'timestampMs': 1000,
      'values': [1, '2.5', double.nan, double.infinity, 'bad', 3],
      'accuracy': 3,
    });

    expect(reading, isNotNull);
    expect(reading!.timestamp.millisecondsSinceEpoch, 1000);
    expect(reading.values, [1.0, 2.5, 3.0]);
  });
}
