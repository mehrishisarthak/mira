import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';

import 'package:mira/core/desktop/mira_window_args.dart';

Future<void> openMiraPrivateBrowserWindow() async {
  if (kIsWeb) return;
  if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;
  try {
    final c = await WindowController.create(
      const WindowConfiguration(
        arguments: kMiraPrivateWindowArgs,
        hiddenAtLaunch: false,
      ),
    );
    await c.show();
  } catch (e, st) {
    debugPrint('MIRA: failed to open private window: $e\n$st');
  }
}
