import 'dart:io';
import 'package:flutter/services.dart';

int _cachedMobileCap = 4;

Future<void> initHibernationLimits() async {
  if (Platform.isAndroid) {
    try {
      final memoryClass = await const MethodChannel('mira/system')
          .invokeMethod<int>('getMemoryClass');
      if (memoryClass == null || memoryClass >= 256) {
        _cachedMobileCap = 4;
      } else if (memoryClass >= 128) {
        _cachedMobileCap = 2;
      } else {
        _cachedMobileCap = 1;
      }
    } catch (e) {
      _cachedMobileCap = 4;
    }
  }
}

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
  // Mobile: each live WebView is a heavy native instance carrying the full
  // content-blocker list. Keep a small LRU working set so memory/CPU don't
  // creep up as tabs accumulate; older tabs hibernate to a lightweight
  // placeholder and reload on focus.
  return _cachedMobileCap;
}
