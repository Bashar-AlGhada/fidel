import 'package:hooks_riverpod/hooks_riverpod.dart';

enum AppThemeMode { light, dark, amoled }

class ThemeModeController extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() => AppThemeMode.dark;

  void setTheme(AppThemeMode mode) {
    state = mode;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, AppThemeMode>(
  ThemeModeController.new,
);
