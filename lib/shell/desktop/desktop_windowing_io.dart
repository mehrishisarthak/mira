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
