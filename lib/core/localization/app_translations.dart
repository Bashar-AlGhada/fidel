import 'package:get/get.dart';

import 'locales/ar.dart';
import 'locales/de_de.dart';
import 'locales/en_us.dart';
import 'locales/es_es.dart';
import 'locales/fr_fr.dart';

/// Aggregates the per-locale maps into the GetX translations contract.
/// Key parity across locales is enforced by
/// `test/localization_parity_test.dart`.
class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'en_US': enUs,
    'de_DE': deDe,
    'fr_FR': frFr,
    'es_ES': esEs,
    'ar': ar,
  };
}
