import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/model/search_engine.dart';
import 'package:mira/model/caching/caching.dart';

// 1. The Available Styles (Colors)
enum MiraStyle {
  tacticalGreen, 
  cyberYellow,   
  neonPurple,    
  oceanBlue,     
  crimsonRed     
}

// 2. The Theme Data Object
class MiraTheme {
  final MiraStyle style;
  final ThemeMode mode;
  final Color primaryColor; 
  final Color accentColor; // DEFINED ACCENT COLOR
  final Color backgroundColor;
  final Color surfaceColor; 

  const MiraTheme({
    required this.style,
    required this.mode,
    required this.primaryColor,
    required this.accentColor, // DEFINED ACCENT COLOR
    this.backgroundColor = const Color(0xFF121212),
    this.surfaceColor = const Color(0xFF1E1E1E),
  });

  factory MiraTheme.fromStyle(MiraStyle style, ThemeMode mode) {
    Color primary;
    switch (style) {
      case MiraStyle.cyberYellow: primary = Colors.yellowAccent; break;
      case MiraStyle.neonPurple: primary = Colors.purpleAccent; break;
      case MiraStyle.oceanBlue: primary = Colors.cyanAccent; break;
      case MiraStyle.crimsonRed: primary = Colors.redAccent; break;
      case MiraStyle.tacticalGreen: primary = Colors.greenAccent; break;
    }

    return MiraTheme(
      style: style,
      mode: mode,
      primaryColor: primary,
      accentColor: primary, // SET ACCENT COLOR
      backgroundColor: mode == ThemeMode.light ? Colors.white : const Color(0xFF121212),
      surfaceColor: mode == ThemeMode.light ? Colors.grey[100]! : const Color(0xFF1E1E1E),
    );
  }
}

// 3. The Logic Controller
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