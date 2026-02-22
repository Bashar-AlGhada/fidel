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
}
