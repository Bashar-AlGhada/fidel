import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../application/providers/units_providers.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/app_section.dart';
import '../../../core/ui/app_states.dart';
import '../../../domain/units/unit_preferences.dart';
import '../../../domain/units/unit_types.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final unitPrefs = ref.watch(unitPreferencesStreamProvider);
    final tokens = context.tokens;

    return Scaffold(
      appBar: AppBar(title: Text('nav.settings'.tr)),
      body: ListView(
        padding: EdgeInsets.all(tokens.space2),
        children: [
          AppSection(
            title: 'settings.appearance'.tr,
            icon: Icons.palette_outlined,
            child: AppCard(
              child: _ThemeModeControl(
                mode: themeMode,
                onChanged: (mode) =>
                    ref.read(themeModeProvider.notifier).setTheme(mode),
              ),
            ),
          ),
          SizedBox(height: tokens.space1),
          AppSection(
            title: 'settings.language'.tr,
            icon: Icons.public,
            child: AppCard(
              onTap: () => _showLanguagePicker(context, ref, locale),
              child: _LanguageTile(current: locale),
            ),
          ),
          SizedBox(height: tokens.space1),
          AppSection(
            title: 'settings.units'.tr,
            icon: Icons.straighten_outlined,
            child: unitPrefs.when(
              skipLoadingOnReload: true,
              data: (prefs) => AppCard(
                child: _UnitsSettings(
                  prefs: prefs,
                  onChanged: (next) =>
                      ref.read(setUnitPreferencesProvider)(next),
                ),
              ),
              loading: () => const AppCard(child: AppLoadingState()),
              error: (err, st) => AppErrorState(
                title: 'availability.unavailable'.tr,
                message: '$err',
                actionLabel: 'action.retry'.tr,
                onAction: () => ref.invalidate(unitPreferencesStreamProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker(
    BuildContext context,
    WidgetRef ref,
    Locale current,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final osResolved = resolveSupportedLocale(
      WidgetsBinding.instance.platformDispatcher.locale,
    );

    final options = <(Locale?, String)>[
      (null, 'settings.languageSystem'.tr),
      for (final l in kSupportedLocales) (l, _languageDisplayName(l)),
    ];

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.space4,
                  0,
                  tokens.space4,
                  tokens.space1,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'settings.language'.tr,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
              ),
              for (final (value, label) in options)
                Builder(
                  builder: (rowContext) {
                    final isSelected = value == null
                        ? current == osResolved
                        : current == value;
                    return ListTile(
                      leading: Icon(
                        value == null ? Icons.public_outlined : Icons.language,
                        color: isSelected
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      title: Text(label),
                      selected: isSelected,
                      trailing: isSelected
                          ? Icon(Icons.check, color: scheme.primary)
                          : null,
                      onTap: () {
                        Navigator.of(rowContext).pop();
                        final next = value ?? osResolved;
                        ref.read(localeProvider.notifier).setLocale(next);
                        Get.updateLocale(next);
                      },
                    );
                  },
                ),
              SizedBox(height: tokens.space1),
            ],
          ),
        );
      },
    );
  }
}

String _languageDisplayName(Locale locale) {
  return switch (locale.languageCode) {
    'en' => 'English',
    'de' => 'Deutsch',
    'fr' => 'Français',
    'es' => 'Español',
    'ar' => 'العربية',
    _ => locale.toLanguageTag(),
  };
}

class _ThemeModeControl extends StatelessWidget {
  const _ThemeModeControl({required this.mode, required this.onChanged});

  final AppThemeMode mode;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<AppThemeMode>(
        selected: {mode},
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: AppThemeMode.light,
            icon: const Icon(Icons.light_mode_outlined),
            label: Text('settings.themeLight'.tr),
          ),
          ButtonSegment(
            value: AppThemeMode.dark,
            icon: const Icon(Icons.dark_mode_outlined),
            label: Text('settings.themeDark'.tr),
          ),
          ButtonSegment(
            value: AppThemeMode.amoled,
            icon: const Icon(Icons.contrast),
            label: Text('settings.themeAmoled'.tr),
          ),
        ],
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({required this.current});

  final Locale current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Row(
      children: [
        const _SettingsIconBadge(icon: Icons.translate),
        SizedBox(width: tokens.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('settings.language'.tr, style: theme.textTheme.bodyLarge),
              Text(
                _languageDisplayName(current),
                style: AppText.muted(context),
              ),
            ],
          ),
        ),
        Icon(
          isRtl ? Icons.chevron_left : Icons.chevron_right,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

class _UnitsSettings extends StatelessWidget {
  const _UnitsSettings({required this.prefs, required this.onChanged});

  final UnitPreferences prefs;
  final ValueChanged<UnitPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _UnitPreferenceRow<TemperatureUnit>(
          label: 'units.temperature'.tr,
          value: prefs.temperature,
          options: [
            (TemperatureUnit.celsius, 'units.celsius'.tr),
            (TemperatureUnit.fahrenheit, 'units.fahrenheit'.tr),
          ],
          onChanged: (v) => onChanged(prefs.copyWith(temperature: v)),
        ),
        SizedBox(height: tokens.space3),
        _UnitPreferenceRow<DataSizeBase>(
          label: 'units.dataSize'.tr,
          value: prefs.dataSizeBase,
          options: [
            (DataSizeBase.base2, 'units.base2'.tr),
            (DataSizeBase.base10, 'units.base10'.tr),
          ],
          onChanged: (v) => onChanged(prefs.copyWith(dataSizeBase: v)),
        ),
        SizedBox(height: tokens.space3),
        _UnitPreferenceRow<RateUnit>(
          label: 'units.rate'.tr,
          value: prefs.rateUnit,
          options: [
            (RateUnit.bytesPerSecond, 'units.bytesPerSecond'.tr),
            (RateUnit.bitsPerSecond, 'units.bitsPerSecond'.tr),
          ],
          onChanged: (v) => onChanged(prefs.copyWith(rateUnit: v)),
        ),
        SizedBox(height: tokens.space3),
        _UnitPreferenceRow<UnitSystem>(
          label: 'units.system'.tr,
          value: prefs.unitSystem,
          options: [
            (UnitSystem.metric, 'units.metric'.tr),
            (UnitSystem.imperial, 'units.imperial'.tr),
          ],
          onChanged: (v) => onChanged(prefs.copyWith(unitSystem: v)),
        ),
      ],
    );
  }
}

class _UnitPreferenceRow<T> extends StatelessWidget {
  const _UnitPreferenceRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        SizedBox(height: tokens.space1),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<T>(
            selected: {value},
            showSelectedIcon: false,
            segments: [
              for (final (optionValue, optionLabel) in options)
                ButtonSegment(value: optionValue, label: Text(optionLabel)),
            ],
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        ),
      ],
    );
  }
}

class _SettingsIconBadge extends StatelessWidget {
  const _SettingsIconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Container(
      width: tokens.space4,
      height: tokens.space4,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
      ),
      child: Icon(icon, size: 20, color: theme.colorScheme.onPrimaryContainer),
    );
  }
}
