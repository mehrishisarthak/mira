import 'dart:io';

/// Desktop: keep several WebViews warm (Chrome-like). Mobile: small LRU to save RAM.
int maxAliveWebViewTabs() {
  if (Platform.isWindows) {
    // WebView2 on Flutter can hit paint glitches with many simultaneous native
    // surfaces. 4 is a safe middle-ground: covers a typical working set without
    // full-reloading on every tab switch, while avoiding surface exhaustion.
    return 4;
  }
  if (Platform.isMacOS || Platform.isLinux) {
    return 64;
  }
  return 3;
}
