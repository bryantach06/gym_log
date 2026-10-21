import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'settings_state.dart';

const _kUseLbs = 'settings_useLbs';
const _kBarWeightKg = 'settings_defaultBarWeightKg';
const _kThemeMode = 'settings_themeMode';

class SettingsCubit extends Cubit<SettingsState> {
  final SharedPreferences _prefs;

  SettingsCubit(this._prefs)
      : super(SettingsState(
          useLbs: _prefs.getBool(_kUseLbs) ?? false,
          defaultBarWeightKg: _prefs.getDouble(_kBarWeightKg) ?? 20.0,
          // Dark is the primary design, so it's the default rather than system.
          themeMode: ThemeMode.values.asNameMap()[_prefs.getString(_kThemeMode)] ??
              ThemeMode.dark,
        ));

  void toggleUnit() {
    final next = !state.useLbs;
    _prefs.setBool(_kUseLbs, next);
    emit(state.copyWith(useLbs: next));
  }

  void setUseLbs(bool useLbs) {
    if (useLbs != state.useLbs) toggleUnit();
  }

  void setThemeMode(ThemeMode mode) {
    _prefs.setString(_kThemeMode, mode.name);
    emit(state.copyWith(themeMode: mode));
  }

  void setDefaultBarWeight(double kg) {
    _prefs.setDouble(_kBarWeightKg, kg);
    emit(state.copyWith(defaultBarWeightKg: kg));
  }
}
