import 'dart:io';

/// Desktop: keep many WebViews warm (Chrome-like). Mobile: small LRU to save RAM.
int maxAliveWebViewTabs() {
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    return 64;
  }
  return 3;
}
