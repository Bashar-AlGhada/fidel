import 'unit_preferences.dart';

abstract class UnitPreferencesRepository {
  Stream<UnitPreferences> watch();
  Future<void> set(UnitPreferences preferences);
}
