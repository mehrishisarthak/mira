import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/entities/theme_entity.dart';
import 'package:mira/core/services/preferences_service.dart';

class ThemeNotifier extends StateNotifier<MiraTheme> {
  final PreferencesService _prefs;

  ThemeNotifier(this._prefs) : super(MiraTheme.fromStyle(MiraStyle.tacticalGreen, ThemeMode.system)) {
    _loadTheme();
  }

  void _loadTheme() {
    final styleIndex = _prefs.getThemeStyle();
    final modeIndex = _prefs.getThemeMode();
    
    final style = MiraStyle.values.asMap().containsKey(styleIndex) 
        ? MiraStyle.values[styleIndex] 
        : MiraStyle.tacticalGreen;
        
    final mode = ThemeMode.values.asMap().containsKey(modeIndex)
        ? ThemeMode.values[modeIndex]
        : ThemeMode.system;

    state = MiraTheme.fromStyle(style, mode);
  }

  void setStyle(MiraStyle style) {
    state = MiraTheme.fromStyle(style, state.mode);
    _prefs.setThemeStyle(style.index);
  }

  void setMode(ThemeMode mode) {
    state = MiraTheme.fromStyle(state.style, mode);
    _prefs.setThemeMode(mode.index);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, MiraTheme>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return ThemeNotifier(prefs);
});
