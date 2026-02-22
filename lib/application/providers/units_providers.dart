import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../domain/units/unit_preferences.dart';
import '../../domain/units/unit_preferences_repository.dart';
import '../../domain/units/units_formatter.dart';
import '../../infrastructure/units/unit_preferences_repository_impl.dart';
import '../../infrastructure/units/units_formatter_impl.dart';

final unitPreferencesRepositoryProvider = Provider<UnitPreferencesRepository>(
  (ref) => UnitPreferencesRepositoryImpl(),
);

final unitPreferencesStreamProvider =
    StreamProvider.autoDispose<UnitPreferences>(
      (ref) => ref.read(unitPreferencesRepositoryProvider).watch(),
    );

final unitsFormatterProvider = Provider<UnitsFormatter>(
  (ref) => UnitsFormatterImpl(),
);

final setUnitPreferencesProvider =
    Provider<Future<void> Function(UnitPreferences)>(
      (ref) =>
          (prefs) => ref.read(unitPreferencesRepositoryProvider).set(prefs),
    );
