import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../domain/units/unit_preferences.dart';
import '../../domain/units/unit_preferences_repository.dart';
import '../../domain/units/units_formatter.dart';
import '../../infrastructure/units/unit_preferences_repository_impl.dart';

final unitPreferencesRepositoryProvider = Provider<UnitPreferencesRepository>((
  ref,
) {
  final repository = UnitPreferencesRepositoryImpl();
  ref.onDispose(repository.dispose);
  return repository;
});

final unitPreferencesStreamProvider =
    StreamProvider.autoDispose<UnitPreferences>(
      (ref) => ref.watch(unitPreferencesRepositoryProvider).watch(),
    );

final unitsFormatterProvider = Provider<UnitsFormatter>(
  (ref) => const UnitsFormatter(),
);

final setUnitPreferencesProvider =
    Provider<Future<void> Function(UnitPreferences)>(
      (ref) =>
          (prefs) => ref.read(unitPreferencesRepositoryProvider).set(prefs),
    );
