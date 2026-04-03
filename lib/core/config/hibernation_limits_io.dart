import 'dart:io';

/// Desktop: keep many WebViews warm (Chrome-like). Mobile: small LRU to save RAM.
int maxAliveWebViewTabs() {
  if (Platform.isWindows) {
    // WebView2 can lose paint/input stability when multiple native surfaces
    // stay mounted in the same Flutter tree. Keep one live view on Windows.
    return 1;
  }
  if (Platform.isMacOS || Platform.isLinux) {
    return 64;
  }
  return 3;
}
