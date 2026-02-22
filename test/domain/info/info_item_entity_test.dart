import 'package:flutter_test/flutter_test.dart';
import 'package:fidel/domain/entities/info/info_availability.dart';
import 'package:fidel/domain/entities/info/info_item_entity.dart';
import 'package:fidel/domain/entities/info/info_item_value.dart';
import 'package:fidel/domain/entities/info/info_sensitivity.dart';

void main() {
  test('InfoItemEntity.unavailable carries no value', () {
    final item = InfoItemEntity.unavailable(labelKey: 'foo');
    expect(item.availability, isNot(InfoAvailability.available));
    expect(item.value, isNull);
  });

  test('InfoItemEntity.redacted never carries raw text', () {
    final item = InfoItemEntity.redacted(labelKey: 'id.serial');
    expect(item.sensitivity, InfoSensitivity.sensitive);
    expect(item.value?.kind, InfoItemValueKind.redacted);
    expect(item.value?.text, isNull);
  });

  test('InfoItemEntity.text cannot be marked sensitive/prohibited', () {
    expect(
      () => InfoItemEntity.text(
        labelKey: 'id.androidId',
        value: 'abc',
        sensitivity: InfoSensitivity.sensitive,
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
