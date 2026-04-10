import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/security_notifier.dart';
import 'package:mira/core/notifiers/theme_notifier.dart';
import 'package:mira/core/config/desktop_user_agent.dart';
import 'package:mira/shell/ad_block/ad_block_service_webview.dart';
import 'package:mira/pages/browser/webview_session.dart' show effectiveDesktopMode;
import 'package:mira/pages/browser_chrome_providers.dart';

void showSecurityDialogForUrl(
  BuildContext context,
  WidgetRef ref,
  String activeUrl,
  Color securityColor,
  Color contentColor,
) {
  if (activeUrl.isEmpty) return;
  final appTheme = ref.read(themeProvider);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: appTheme.surfaceColor,
      title: Text(
        activeUrl.startsWith("https://")
            ? "Connection Secure"
            : "Connection Not Secure",
        style: TextStyle(color: securityColor),
      ),
      content: Text(
        activeUrl.startsWith("https://")
            ? "MIRA verified this site uses a valid SSL certificate."
            : "This site uses HTTP. Your data is not encrypted.",
        style: TextStyle(color: contentColor.withAlpha(179)),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text("Got it")),
      ],
    ),
  );
}

Future<void> applyMainScreenWebViewSettings(
  WidgetRef ref, {
  bool forceReload = false,
}) async {
  final controller = ref.read(browserChromeProvider).controller;
  if (controller == null) return;

  final theme = ref.read(themeProvider);
  final securityState = ref.read(securityProvider);
  final isGhost = ref.read(isGhostModeProvider);

  final forceDarkSetting = (theme.mode == ThemeMode.light)
      ? ForceDark.OFF
      : (theme.mode == ThemeMode.dark ? ForceDark.ON : ForceDark.AUTO);

  final desktopMode = effectiveDesktopMode(securityState.isDesktopMode);
  final settings = InAppWebViewSettings(
    incognito: isGhost || securityState.isIncognito,
    clearCache: false,
    useOnDownloadStart: true,
    contentBlockers: securityState.isAdBlockEnabled
        ? AdBlockServiceWebview.contentBlockers
        : [],
    forceDark: forceDarkSetting,
    algorithmicDarkeningAllowed: (theme.mode == ThemeMode.dark),
    useHybridComposition: !kIsWeb && Platform.isAndroid,
    userAgent: desktopModeUserAgent(
      isDesktop: !kIsWeb &&
          (Platform.isWindows || Platform.isMacOS || Platform.isLinux),
      desktopModeOn: desktopMode,
    ),
    preferredContentMode: desktopMode
        ? UserPreferredContentMode.DESKTOP
        : UserPreferredContentMode.MOBILE,
  );

  try {
    await controller.setSettings(settings: settings);
    if (forceReload) {
      await controller.reload();
    }
  } catch (e) {
    debugPrint("MIRA: Failed to update WebView settings: $e");
  }
}
