import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
import '../data/local/local_data_store.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/almanac_tokens.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

final localDataStoreProvider = Provider<LocalDataStore>((ref) {
  throw UnimplementedError('LocalDataStore must be provided in main()');
});

/// Инкрементируется при изменении рабочих расписаний (перезагрузка календаря).
final schedulesVersionProvider = StateProvider<int>((ref) => 0);

final savingsGoalsVersionProvider = StateProvider<int>((ref) => 0);

/// Инкремент при изменении URL/API в профиле (пересборка remote API).
final platformSettingsRevisionProvider = StateProvider<int>((ref) => 0);

final eventLocksRevisionProvider = StateProvider<int>((ref) => 0);

/// Текущая локаль UI (совпадает с [MaterialApp.locale]).
class AppLocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final code = ref.read(localDataStoreProvider).localeLanguageCode;
    return AppLocalizations.localeFromCode(code);
  }

  void setLanguageCode(String languageCode) {
    final locale = AppLocalizations.localeFromCode(languageCode);
    if (state.languageCode == locale.languageCode) return;
    state = locale;
    ref.read(localDataStoreProvider).applyLocale(languageCode);
    ref.read(schedulesVersionProvider.notifier).state++;
  }

  /// Подтягивает локаль из [LocalDataStore] после restore/sync без записи.
  void syncFromStore() {
    final code = ref.read(localDataStoreProvider).localeLanguageCode;
    state = AppLocalizations.localeFromCode(code);
  }
}

final appLocaleProvider = NotifierProvider<AppLocaleNotifier, Locale>(
  AppLocaleNotifier.new,
);

/// Инкрементируется при сохранении/удалении пользовательских пресетов акцента.
final accentPresetsRevisionProvider = StateProvider<int>((ref) => 0);

class WeekHourZoomLevelNotifier extends Notifier<int> {
  @override
  int build() => ref.read(localDataStoreProvider).weekHourZoomLevel;

  void setValue(int value) {
    final clamped = value.clamp(1, 2);
    if (state == clamped) return;
    state = clamped;
    ref.read(localDataStoreProvider).setWeekHourZoomLevel(clamped);
  }

  void syncFromStore() {
    state = ref.read(localDataStoreProvider).weekHourZoomLevel;
  }
}

final weekHourZoomLevelProvider =
    NotifierProvider<WeekHourZoomLevelNotifier, int>(
      WeekHourZoomLevelNotifier.new,
    );

/// Встроенные + сохранённые пользователем цвета акцента.
final accentPresetColorsProvider = Provider<List<Color>>((ref) {
  ref.watch(accentPresetsRevisionProvider);

  final store = ref.watch(localDataStoreProvider);

  final seen = <int>{};
  final result = <Color>[];
  for (final color in [
    ...AlmanacBrand.accentPresets,
    ...store.savedAccentPresets,
  ]) {
    final argb = color.toARGB32();
    if (seen.add(argb)) {
      result.add(color);
    }
  }
  return result;
});
