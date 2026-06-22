import 'package:flutter/widgets.dart';

/// Bundled JetBrains Mono. Drop-in replacement for the old
/// `GoogleFonts.jetBrainsMono()` with the same call shape, but the font ships
/// as an asset (declared in
/// pubspec.yaml) instead of being fetched over the network at runtime — which
/// caused per-screen first-paint flicker and offline failures (O-40).
///
/// JetBrainsMono.ttf is a variable font; Flutter maps [fontWeight] to its
/// `wght` axis, so a single asset covers every weight used in the app.
TextStyle jetBrainsMono({
  Color? color,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  double? letterSpacing,
  double? wordSpacing,
  double? height,
  TextDecoration? decoration,
  Color? backgroundColor,
  List<Shadow>? shadows,
}) {
  return TextStyle(
    fontFamily: 'JetBrainsMono',
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    letterSpacing: letterSpacing,
    wordSpacing: wordSpacing,
    height: height,
    decoration: decoration,
    backgroundColor: backgroundColor,
    shadows: shadows,
  );
}
