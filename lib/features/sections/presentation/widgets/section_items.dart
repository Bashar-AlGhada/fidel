import '../../../../domain/entities/info/info_section_entity.dart';

/// Returns the stored text value of the first item matching [labelKey].
String? findItemText(InfoSectionEntity section, String labelKey) {
  for (final item in section.items) {
    if (item.labelKey != labelKey) continue;
    return item.value?.text;
  }
  return null;
}
