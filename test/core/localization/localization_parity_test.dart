import 'package:flutter_test/flutter_test.dart';
import 'package:fidel/core/localization/locales/ar.dart';
import 'package:fidel/core/localization/locales/de_de.dart';
import 'package:fidel/core/localization/locales/en_us.dart';
import 'package:fidel/core/localization/locales/es_es.dart';
import 'package:fidel/core/localization/locales/fr_fr.dart';

void main() {
  const locales = <String, Map<String, String>>{
    'en_US': enUs,
    'de_DE': deDe,
    'fr_FR': frFr,
    'es_ES': esEs,
    'ar': ar,
  };

  test('all five locale maps have identical key sets', () {
    final reference = enUs.keys.toSet();
    for (final entry in locales.entries) {
      final keys = entry.value.keys.toSet();
      final missing = reference.difference(keys);
      final extra = keys.difference(reference);
      expect(
        missing,
        isEmpty,
        reason: '${entry.key} is missing keys: ${missing.take(5).toList()}',
      );
      expect(
        extra,
        isEmpty,
        reason: '${entry.key} has extra keys: ${extra.take(5).toList()}',
      );
      expect(keys.length, enUs.length, reason: '${entry.key} key count');
    }
  });

  test('no locale map contains an empty value', () {
    for (final entry in locales.entries) {
      for (final e in entry.value.entries) {
        expect(e.value, isNotEmpty, reason: '${entry.key}.${e.key}');
      }
    }
  });

  // Duplicate keys cannot occur inside a single const map literal (the
  // compiler rejects them), so no dedicated check is needed here.
}
