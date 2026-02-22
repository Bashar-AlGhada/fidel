import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/units/unit_preferences.dart';
import '../../domain/units/unit_preferences_repository.dart';
import '../../domain/units/unit_types.dart';

class UnitPreferencesRepositoryImpl implements UnitPreferencesRepository {
  UnitPreferencesRepositoryImpl() {
    if (!_isTest) {
      unawaited(_load());
    }
  }

  static const bool _isTest = bool.fromEnvironment('FLUTTER_TEST');

  static const _kTemperature = 'units.temperature';
  static const _kUnitSystem = 'units.unitSystem';
  static const _kDataSizeBase = 'units.dataSizeBase';
  static const _kRateUnit = 'units.rateUnit';

  final BehaviorSubject<UnitPreferences> _subject =
      BehaviorSubject<UnitPreferences>.seeded(UnitPreferences.defaults);

  @override
  Stream<UnitPreferences> watch() => _subject.stream;

  @override
  Future<void> set(UnitPreferences preferences) async {
    if (!_isTest) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kTemperature, preferences.temperature.name);
        await prefs.setString(_kUnitSystem, preferences.unitSystem.name);
        await prefs.setString(_kDataSizeBase, preferences.dataSizeBase.name);
        await prefs.setString(_kRateUnit, preferences.rateUnit.name);
      } catch (_) {}
    }
    _subject.add(preferences);
  }

  Future<void> _load() async {
    String? temp;
    String? unitSystem;
    String? dataSizeBase;
    String? rateUnit;

    try {
      final prefs = await SharedPreferences.getInstance();
      temp = prefs.getString(_kTemperature);
      unitSystem = prefs.getString(_kUnitSystem);
      dataSizeBase = prefs.getString(_kDataSizeBase);
      rateUnit = prefs.getString(_kRateUnit);
    } catch (_) {}

    final next = UnitPreferences.defaults.copyWith(
      temperature:
          _parseEnum(TemperatureUnit.values, temp) ??
          UnitPreferences.defaults.temperature,
      unitSystem:
          _parseEnum(UnitSystem.values, unitSystem) ??
          UnitPreferences.defaults.unitSystem,
      dataSizeBase:
          _parseEnum(DataSizeBase.values, dataSizeBase) ??
          UnitPreferences.defaults.dataSizeBase,
      rateUnit:
          _parseEnum(RateUnit.values, rateUnit) ??
          UnitPreferences.defaults.rateUnit,
    );

    _subject.add(next);
  }

  T? _parseEnum<T extends Enum>(List<T> values, String? name) {
    if (name == null || name.isEmpty) return null;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}
