import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/security_notifier.dart';
import 'package:mira/core/notifiers/theme_notifier.dart';
import 'package:mira/pages/browser_chrome_providers.dart';
import 'package:mira/core/services/browser_engine_blueprints.dart';

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
  final engine = ref.read(browserChromeProvider).engine;
  if (engine == null) return;

  final theme = ref.read(themeProvider);
  final securityState = ref.read(securityProvider);

  final config = BrowserEngineConfig(
    isDesktopMode: securityState.isDesktopMode,
    isAdBlockEnabled: securityState.isAdBlockEnabled,
    isDarkMode: theme.mode == ThemeMode.dark,
  );

  try {
    await engine.updateSettings(config);
    if (forceReload) {
      await engine.reload();
    }
  } catch (e) {
    debugPrint("MIRA: Failed to update engine settings: $e");
  }
}
