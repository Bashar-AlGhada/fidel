import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/units_providers.dart';
import '../../../application/sampling/active_module.dart';
import '../../../application/sampling/sampling_provider.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../domain/units/unit_preferences.dart';
import '../../../domain/units/unit_types.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeModule = ref.watch(activeModuleProvider);
    if (activeModule != ActiveModule.settings) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(activeModuleProvider.notifier)
            .setModule(ActiveModule.settings);
      });
    }

    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final unitPrefs = ref.watch(unitPreferencesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: Text('nav.settings'.tr)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('settings.theme'.tr),
          DropdownButton<AppThemeMode>(
            value: themeMode,
            onChanged: (v) {
              if (v == null) return;
              ref.read(themeModeProvider.notifier).setTheme(v);
            },
            items: const [
              DropdownMenuItem(value: AppThemeMode.light, child: Text('Light')),
              DropdownMenuItem(value: AppThemeMode.dark, child: Text('Dark')),
              DropdownMenuItem(
                value: AppThemeMode.amoled,
                child: Text('AMOLED'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('settings.language'.tr),
          DropdownButton<Locale>(
            value: locale,
            onChanged: (v) {
              if (v == null) return;
              ref.read(localeProvider.notifier).setLocale(v);
              Get.updateLocale(v);
            },
            items: const [
              DropdownMenuItem(
                value: Locale('en', 'US'),
                child: Text('English'),
              ),
              DropdownMenuItem(
                value: Locale('de', 'DE'),
                child: Text('Deutsch'),
              ),
              DropdownMenuItem(
                value: Locale('fr', 'FR'),
                child: Text('Français'),
              ),
              DropdownMenuItem(
                value: Locale('es', 'ES'),
                child: Text('Español'),
              ),
              DropdownMenuItem(value: Locale('ar'), child: Text('العربية')),
            ],
          ),
          const SizedBox(height: 24),
          Text('settings.units'.tr),
          unitPrefs.when(
            data: (prefs) => _UnitsSettings(
              prefs: prefs,
              onChanged: (next) => ref.read(setUnitPreferencesProvider)(next),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
            error: (err, st) => Text('availability.unavailable'.tr),
          ),
        ],
      ),
    );
  }
}

class _UnitsSettings extends StatelessWidget {
  const _UnitsSettings({required this.prefs, required this.onChanged});

  final UnitPreferences prefs;
  final ValueChanged<UnitPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('units.temperature'.tr)),
            DropdownButton<TemperatureUnit>(
              value: prefs.temperature,
              onChanged: (v) =>
                  v == null ? null : onChanged(prefs.copyWith(temperature: v)),
              items: [
                DropdownMenuItem(
                  value: TemperatureUnit.celsius,
                  child: Text('units.celsius'.tr),
                ),
                DropdownMenuItem(
                  value: TemperatureUnit.fahrenheit,
                  child: Text('units.fahrenheit'.tr),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            Expanded(child: Text('units.dataSize'.tr)),
            DropdownButton<DataSizeBase>(
              value: prefs.dataSizeBase,
              onChanged: (v) =>
                  v == null ? null : onChanged(prefs.copyWith(dataSizeBase: v)),
              items: [
                DropdownMenuItem(
                  value: DataSizeBase.base2,
                  child: Text('units.base2'.tr),
                ),
                DropdownMenuItem(
                  value: DataSizeBase.base10,
                  child: Text('units.base10'.tr),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            Expanded(child: Text('units.rate'.tr)),
            DropdownButton<RateUnit>(
              value: prefs.rateUnit,
              onChanged: (v) =>
                  v == null ? null : onChanged(prefs.copyWith(rateUnit: v)),
              items: [
                DropdownMenuItem(
                  value: RateUnit.bytesPerSecond,
                  child: Text('units.bytesPerSecond'.tr),
                ),
                DropdownMenuItem(
                  value: RateUnit.bitsPerSecond,
                  child: Text('units.bitsPerSecond'.tr),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            Expanded(child: Text('units.system'.tr)),
            DropdownButton<UnitSystem>(
              value: prefs.unitSystem,
              onChanged: (v) =>
                  v == null ? null : onChanged(prefs.copyWith(unitSystem: v)),
              items: [
                DropdownMenuItem(
                  value: UnitSystem.metric,
                  child: Text('units.metric'.tr),
                ),
                DropdownMenuItem(
                  value: UnitSystem.imperial,
                  child: Text('units.imperial'.tr),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
