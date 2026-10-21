part of 'settings_cubit.dart';

class SettingsState extends Equatable {
  final bool useLbs;
  final double defaultBarWeightKg;
  final ThemeMode themeMode;

  const SettingsState({
    this.useLbs = false,
    this.defaultBarWeightKg = 20.0,
    this.themeMode = ThemeMode.dark,
  });

  SettingsState copyWith({bool? useLbs, double? defaultBarWeightKg, ThemeMode? themeMode}) =>
      SettingsState(
        useLbs: useLbs ?? this.useLbs,
        defaultBarWeightKg: defaultBarWeightKg ?? this.defaultBarWeightKg,
        themeMode: themeMode ?? this.themeMode,
      );

  @override
  List<Object?> get props => [useLbs, defaultBarWeightKg, themeMode];
}
