import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum MainScreenHapticKind {
  light,
  medium,
  selection,
}

/// Platform-safe haptic trigger. No-ops on desktop and web.
void miraHaptic(MainScreenHapticKind kind) {
  if (kIsWeb) return;
  if (!(Platform.isAndroid || Platform.isIOS)) return;
  switch (kind) {
    case MainScreenHapticKind.light:
      HapticFeedback.lightImpact();
    case MainScreenHapticKind.medium:
      HapticFeedback.mediumImpact();
    case MainScreenHapticKind.selection:
      HapticFeedback.selectionClick();
  }
}
