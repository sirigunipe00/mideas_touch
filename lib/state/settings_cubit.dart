import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/l10n/strings.dart';

class SettingsState {
  const SettingsState({this.lang = 'en', this.themeMode = ThemeMode.system});

  /// `en` or `hi`.
  final String lang;
  final ThemeMode themeMode;

  Strings get t => Strings(lang);

  SettingsState copyWith({String? lang, ThemeMode? themeMode}) =>
      SettingsState(
          lang: lang ?? this.lang, themeMode: themeMode ?? this.themeMode);
}

/// Language (English / Hindi) and theme (Light / Dark / System).
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(const SettingsState());

  void setLanguage(String lang) => emit(state.copyWith(lang: lang));

  void setThemeMode(ThemeMode mode) => emit(state.copyWith(themeMode: mode));
}
