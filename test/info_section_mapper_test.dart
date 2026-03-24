import 'package:flutter_test/flutter_test.dart';

import 'package:fidel/infrastructure/mappers/info_section_mapper.dart';

void main() {
  test('deviceAndBuild maps known keys into items', () {
    final mapper = InfoSectionMapper();

    final section = mapper.deviceAndBuild(
      device: {
        'manufacturer': 'Google',
        'model': 'Pixel',
        'supportedAbis': ['arm64-v8a', 'armeabi-v7a'],
      },
      build: {'sdkInt': 34, 'release': '14'},
    );

    expect(section.id, 'device-build');
    expect(section.items, isNotEmpty);

    final manufacturer = section.items.firstWhere(
      (i) => i.labelKey == 'device.manufacturer',
    );
    expect(manufacturer.value?.text, 'Google');

    final abis = section.items.firstWhere(
      (i) => i.labelKey == 'device.supportedAbis',
    );
    expect(abis.value?.text, contains('arm64-v8a'));
  });

  test('null values map to unavailable item', () {
    final mapper = InfoSectionMapper();

    final section = mapper.display({'widthPx': null, 'heightPx': 100});

    final width = section.items.firstWhere(
      (i) => i.labelKey == 'display.widthPx',
    );
    expect(width.value, isNull);

    final height = section.items.firstWhere(
      (i) => i.labelKey == 'display.heightPx',
    );
    expect(height.value?.text, '100');
  });

  test('display refresh rates are compactly formatted', () {
    final mapper = InfoSectionMapper();

    final section = mapper.display({
      'refreshRatesHz': [60.0, 90.0, 120.25],
    });

    final rates = section.items.firstWhere(
      (i) => i.labelKey == 'display.refreshRatesHz',
    );
    expect(rates.value?.text, '60, 90, 120.25 Hz');
  });

  test('thermal map payload is normalized into temperature rows', () {
    final mapper = InfoSectionMapper();

    final section = mapper.thermal({
      'temperatures': {'batteryTempC': 34.5, 'cpuTempC': 47},
    });

    final temps = section.items.firstWhere(
      (i) => i.labelKey == 'thermal.temperatures',
    );
    expect(temps.value?.text, contains('battery'));
    expect(temps.value?.text, contains('cpu'));
    expect(temps.value?.text, contains('34.5'));
    expect(temps.value?.text, contains('47.0'));
  });

  test('thermal list payload keeps all thermal zones', () {
    final mapper = InfoSectionMapper();

    final section = mapper.thermal({
      'temperatures': [
        {'name': 'GPU', 'type': 'gpu', 'valueC': 63.2},
        {'name': 'Skin', 'type': 'skin', 'valueC': 38.4},
      ],
    });

    final temps = section.items.firstWhere(
      (i) => i.labelKey == 'thermal.temperatures',
    );
    expect(temps.value?.text, contains('GPU'));
    expect(temps.value?.text, contains('Skin'));
    expect(temps.value?.text, contains('63.2'));
    expect(temps.value?.text, contains('38.4'));
  });
}
