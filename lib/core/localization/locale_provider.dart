import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/environment.dart';
import '../logging/app_logger.dart';

/// Canonical supported-locale list. main.dart consumes this so the
/// settings dropdown, restore logic and Material resolution can never
/// drift apart.
const List<Locale> kSupportedLocales = [
  Locale('en', 'US'),
  Locale('de', 'DE'),
  Locale('fr', 'FR'),
  Locale('es', 'ES'),
  Locale('ar'),
];

const Locale kFallbackLocale = Locale('en', 'US');

/// Clamps any incoming locale (OS locale, stale pref) onto the supported
/// set: exact language+country match first, then same language, then the
/// fallback — so the dropdown's value-in-items invariant always holds.
Locale resolveSupportedLocale(Locale raw) {
  for (final l in kSupportedLocales) {
    if (l.languageCode == raw.languageCode &&
        l.countryCode == raw.countryCode) {
      return l;
    }
  }
  for (final l in kSupportedLocales) {
    if (l.languageCode == raw.languageCode) return l;
  }
  return kFallbackLocale;
}

/// Serializes a [Locale] to its persisted form (`en`, `de_DE`, ...).
String _serializeLocale(Locale locale) {
  final country = locale.countryCode;
  return country == null || country.isEmpty
      ? locale.languageCode
      : '${locale.languageCode}_$country';
}

/// Rebuilds a [Locale] from [_serializeLocale] output; returns null for
/// unsupported languages so stale prefs cannot hijack the app.
Locale? _parseLocale(String raw) {
  final parts = raw.split('_');
  final candidate = parts.length > 1
      ? Locale(parts.first, parts[1])
      : Locale(parts.first);
  // Resolve against the supported set; unknown languages are dropped.
  if (kSupportedLocales.any((l) => l.languageCode == candidate.languageCode)) {
    return resolveSupportedLocale(candidate);
  }
  return null;
}

class LocaleController extends Notifier<Locale> {
  static const String _kLocale = 'ui.locale';

  bool _userModified = false;

  @override
  Locale build() {
    unawaited(_restore());
    return resolveSupportedLocale(
      WidgetsBinding.instance.platformDispatcher.locale,
    );
  }

  void setLocale(Locale locale) {
    _userModified = true;
    state = locale;
    unawaited(_persist(locale));
  }

  Future<void> _restore() async {
    if (appIsTest) return;
    String? stored;
    try {
      final prefs = await SharedPreferences.getInstance();
      stored = prefs.getString(_kLocale);
    } catch (e, st) {
      AppLog.warn('Failed to read saved locale', error: e, stackTrace: st);
      return;
    }
    if (stored == null || _userModified) return;

    final restored = _parseLocale(stored);
    if (restored != null) state = restored;
  }

  Future<void> _persist(Locale locale) async {
    if (appIsTest) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLocale, _serializeLocale(locale));
    } catch (e, st) {
      AppLog.warn('Failed to persist locale', error: e, stackTrace: st);
    }
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);
