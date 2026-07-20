import 'dart:io';

import 'package:window_manager/window_manager.dart';

Future<void> desktopWindowManagerInit() async {
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
  }
}

Future<void> desktopSetWindowTitle(String title) async {
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.setTitle(title);
  }
}

/// OS-level fullscreen (hides the taskbar/dock too), not just our own chrome
/// — matches what an actual browser does when a page's video goes fullscreen.
Future<void> desktopSetFullScreen(bool fullscreen) async {
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.setFullScreen(fullscreen);
  }
}
