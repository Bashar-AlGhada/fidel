import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/environment.dart';
import '../logging/app_logger.dart';

enum AppThemeMode { light, dark, amoled }

class ThemeModeController extends Notifier<AppThemeMode> {
  static const String _kTheme = 'ui.theme';

  bool _userModified = false;

  @override
  AppThemeMode build() {
    unawaited(_restore());
    return AppThemeMode.dark;
  }

  void setTheme(AppThemeMode mode) {
    _userModified = true;
    state = mode;
    unawaited(_persist(mode));
  }

  Future<void> _restore() async {
    if (appIsTest) return;
    String? stored;
    try {
      final prefs = await SharedPreferences.getInstance();
      stored = prefs.getString(_kTheme);
    } catch (e, st) {
      AppLog.warn('Failed to read saved theme', error: e, stackTrace: st);
      return;
    }
    if (stored == null || _userModified) return;

    for (final mode in AppThemeMode.values) {
      if (mode.name == stored) state = mode;
    }
  }

  Future<void> _persist(AppThemeMode mode) async {
    if (appIsTest) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTheme, mode.name);
    } catch (e, st) {
      AppLog.warn('Failed to persist theme', error: e, stackTrace: st);
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, AppThemeMode>(
  ThemeModeController.new,
);
