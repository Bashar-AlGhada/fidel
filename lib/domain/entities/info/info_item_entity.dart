import 'info_availability.dart';
import 'info_item_value.dart';
import 'info_sensitivity.dart';

class InfoItemEntity {
  InfoItemEntity._({
    required this.labelKey,
    required this.availability,
    required this.sensitivity,
    required this.value,
  }) {
    final checkedValue = value;
    if (availability != InfoAvailability.available && checkedValue != null) {
      throw ArgumentError.value(
        checkedValue,
        'value',
        'A non-available item must not have a value.',
      );
    }
    if (sensitivity != InfoSensitivity.public &&
        checkedValue != null &&
        checkedValue.kind == InfoItemValueKind.text) {
      throw ArgumentError.value(
        checkedValue,
        'value',
        'Sensitive/prohibited items must not carry raw text values.',
      );
    }
  }

  final String labelKey;
  final InfoAvailability availability;
  final InfoSensitivity sensitivity;
  final InfoItemValue? value;

  factory InfoItemEntity.text({
    required String labelKey,
    required String value,
    InfoSensitivity sensitivity = InfoSensitivity.public,
  }) {
    return InfoItemEntity._(
      labelKey: labelKey,
      availability: InfoAvailability.available,
      sensitivity: sensitivity,
      value: InfoItemValue.text(value),
    );
  }

  factory InfoItemEntity.redacted({
    required String labelKey,
    InfoSensitivity sensitivity = InfoSensitivity.sensitive,
  }) {
    return InfoItemEntity._(
      labelKey: labelKey,
      availability: InfoAvailability.available,
      sensitivity: sensitivity,
      value: const InfoItemValue.redacted(),
    );
  }

  factory InfoItemEntity.hidden({
    required String labelKey,
    InfoSensitivity sensitivity = InfoSensitivity.prohibited,
  }) {
    return InfoItemEntity._(
      labelKey: labelKey,
      availability: InfoAvailability.available,
      sensitivity: sensitivity,
      value: const InfoItemValue.hidden(),
    );
  }

  factory InfoItemEntity.unavailable({
    required String labelKey,
    InfoSensitivity sensitivity = InfoSensitivity.public,
    InfoAvailability availability = InfoAvailability.unavailable,
  }) {
    if (availability == InfoAvailability.available) {
      throw ArgumentError.value(
        availability,
        'availability',
        'Use one of the available factories instead.',
      );
    }
    return InfoItemEntity._(
      labelKey: labelKey,
      availability: availability,
      sensitivity: sensitivity,
      value: null,
    );
  }
}
