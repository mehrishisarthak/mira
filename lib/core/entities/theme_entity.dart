import 'package:flutter/material.dart';

enum MiraStyle {
  tacticalGreen, 
  cyberYellow,   
  neonPurple,    
  oceanBlue,     
  crimsonRed     
}

class MiraTheme {
  final MiraStyle style;
  final ThemeMode mode;
  final Color primaryColor; 
  final Color accentColor;
  final Color backgroundColor;
  final Color surfaceColor; 

  const MiraTheme({
    required this.style,
    required this.mode,
    required this.primaryColor,
    required this.accentColor,
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
      accentColor: primary,
      backgroundColor: mode == ThemeMode.light ? Colors.white : const Color(0xFF121212),
      surfaceColor: mode == ThemeMode.light ? Colors.grey[100]! : const Color(0xFF1E1E1E),
    );
  }
}
