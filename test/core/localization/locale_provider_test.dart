import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fidel/core/localization/locale_provider.dart';

void main() {
  group('resolveSupportedLocale', () {
    test('exact language+country match returns the supported entry', () {
      final resolved = resolveSupportedLocale(const Locale('de', 'DE'));
      expect(resolved.languageCode, 'de');
      expect(resolved.countryCode, 'DE');
      expect(kSupportedLocales, contains(resolved));
    });

    test('language-only input falls back to same-language entry', () {
      final resolved = resolveSupportedLocale(const Locale('de'));
      expect(resolved.languageCode, 'de');
      expect(resolved.countryCode, 'DE');

      final fr = resolveSupportedLocale(const Locale('fr', 'CA'));
      expect(fr.countryCode, 'FR', reason: 'en_GB-style variants map to FR');
    });

    test('unknown language falls back to kFallbackLocale', () {
      expect(
        identical(resolveSupportedLocale(const Locale('ja')), kFallbackLocale),
        isTrue,
      );
      // Unknown country on a known language still resolves by language.
      expect(
        resolveSupportedLocale(const Locale('xx', 'YY')).languageCode,
        'en',
      );
    });

    test('ar has no country code and resolves to itself', () {
      final ar = kSupportedLocales.last;
      expect(ar.countryCode, isNull);
      expect(identical(resolveSupportedLocale(const Locale('ar')), ar), isTrue);
    });

    test('every supported locale round-trips to its own instance', () {
      // Indirectly covers _serializeLocale/_parseLocale: persisted
      // strings rebuilt from these locales must land on the exact
      // canonical instances.
      for (final l in kSupportedLocales) {
        expect(
          identical(resolveSupportedLocale(l), l),
          isTrue,
          reason: '$l does not round-trip',
        );
      }
    });
  });
}
