import 'package:flutter/material.dart';

/// Matte black (#282828) — used instead of pure black for large surfaces to reduce eye strain.
const Color kMiraMatteBlack = Color(0xFF282828);

/// Dark theme surface slightly above [kMiraMatteBlack] for elevation separation.
const Color kMiraMatteSurface = Color(0xFF323232);

/// Light-mode primary text (same ink as matte black — consistent with dark chrome).
const Color kMiraInkPrimary = kMiraMatteBlack;

/// Light-mode secondary / hint / de-emphasized text.
final Color kMiraInkMuted = kMiraMatteBlack.withValues(alpha: 0.55);

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
    this.backgroundColor = kMiraMatteBlack,
    this.surfaceColor = kMiraMatteSurface,
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
      backgroundColor: mode == ThemeMode.light ? Colors.white : kMiraMatteBlack,
      surfaceColor: mode == ThemeMode.light ? Colors.grey[100]! : kMiraMatteSurface,
    );
  }
}
