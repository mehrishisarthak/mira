import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart'
    show CookieManager, WebStorageManager;
import 'package:qyx/pages/main_screen/main_screen_haptics.dart';
import 'package:qyx/constants/app_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qyx/core/notifiers/history_notifier.dart';

// Models
import 'package:qyx/core/entities/theme_entity.dart';
import 'package:qyx/core/notifiers/theme_notifier.dart';
import 'package:qyx/core/notifiers/security_notifier.dart';
import 'package:qyx/core/notifiers/ghost_notifier.dart';
import 'package:qyx/core/notifiers/tab_notifier.dart';
import 'package:qyx/core/services/download_provider.dart';
import 'package:qyx/pages/history_screen.dart';
import 'package:qyx/pages/book_marks_screen.dart';
import 'package:qyx/pages/downloads_screen.dart';
import 'package:qyx/pages/browser_sheet.dart';

import 'package:qyx/core/ui/qyx_toast.dart';
import 'package:qyx/pages/browser_chrome_providers.dart';
import 'package:qyx/core/notifiers/hibernation_notifier.dart';
import 'package:qyx/core/services/database_providers.dart';
import 'package:qyx/shell/desktop/open_private_browser_window.dart';

/// Close the menu route, then push [page] on the root navigator (desktop popup).
void _popMenuThenPush(BuildContext context, Widget page) {
  final rootNav = Navigator.of(context, rootNavigator: true);
  Navigator.of(context).pop();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (rootNav.context.mounted) {
      rootNav.push(MaterialPageRoute<void>(builder: (_) => page));
    }
  });
}

/// Close the menu, then show the search-engine sheet anchored to the browser shell.
void _popMenuThenShowSearchSheet(BuildContext context) {
  final rootNav = Navigator.of(context, rootNavigator: true);
  Navigator.of(context).pop();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!rootNav.context.mounted) return;
    showModalBottomSheet<void>(
      context: rootNav.context,
      backgroundColor: Colors.transparent,
      builder: (_) => const BrowserSheet(),
    );
  });
}

class MiraMenuPage extends ConsumerWidget {
  const MiraMenuPage({super.key, this.desktopOverlay = false});

  final bool desktopOverlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final securityState = ref.watch(securityProvider);
    final isGhost = ref.watch(isGhostModeProvider);
    final theme = ref.watch(themeProvider);

    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);

    // Mirrors the guard in InAppWebViewEngine._buildContentBlockers: WebKit
    // ContentBlockers exist on Android/iOS/macOS only. Note macOS IS supported,
    // so this is deliberately not `!isDesktop`.
    final adBlockSupported = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);

    final isLight = theme.mode == ThemeMode.light;
    final appTextColor = isLight ? kMiraInkPrimary : Colors.white;
    final primaryAccent = isGhost ? Colors.redAccent : theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.surfaceColor,
        leading: IconButton(
          icon: Icon(
            desktopOverlay ? Icons.close : desktopOverlay ? Icons.close : Icons.arrow_back,
            color: appTextColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Q Y X',
          style: jetBrainsMono(
            color: primaryAccent,
            fontSize: 18,
            letterSpacing: 5,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: appTextColor.withAlpha(26)),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // â”€â”€ NAVIGATION â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _sectionLabel("NAVIGATE", primaryAccent),

            ListTile(
              leading: Icon(Icons.history, color: appTextColor.withAlpha(179)),
              title: Text('History', style: TextStyle(color: appTextColor)),
              onTap: () {
                if (desktopOverlay) {
                  _popMenuThenPush(context, const HistoryPage());
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HistoryPage()),
                  );
                }
              },
            ),

            ListTile(
              leading:
                  Icon(Icons.bookmark_border, color: appTextColor.withAlpha(179)),
              title: Text('Bookmarks', style: TextStyle(color: appTextColor)),
              enabled: !isGhost,
              onTap: isGhost
                  ? null
                  : () {
                      if (desktopOverlay) {
                        _popMenuThenPush(context, const BookmarksPage());
                      } else {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const BookmarksPage()),
                        );
                      }
                    },
            ),

            ListTile(
              leading:
                  Icon(Icons.download, color: appTextColor.withAlpha(179)),
              title: Text('Downloads', style: TextStyle(color: appTextColor)),
              onTap: () {
                if (desktopOverlay) {
                  _popMenuThenPush(context, const DownloadsPage());
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const DownloadsPage()),
                  );
                }
              },
            ),

            ListTile(
              leading: Icon(Icons.search, color: appTextColor.withAlpha(179)),
              title: Text('Search Engine',
                  style: TextStyle(color: appTextColor)),
              onTap: () {
                if (desktopOverlay) {
                  _popMenuThenShowSearchSheet(context);
                } else {
                  final rootNav = Navigator.of(context, rootNavigator: true);
                  Navigator.pop(context);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!rootNav.context.mounted) return;
                    showModalBottomSheet<void>(
                      context: rootNav.context,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const BrowserSheet(),
                    );
                  });
                }
              },
            ),

            Divider(color: appTextColor.withAlpha(51)),

            // â”€â”€ PAGE ACTIONS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _sectionLabel("PAGE ACTIONS", primaryAccent),

            ListTile(
              leading: Icon(Icons.link, color: appTextColor.withAlpha(179)),
              title: Text('Copy URL', style: TextStyle(color: appTextColor)),
              onTap: () {
                final url = ref.read(tabsProvider).safeActiveTab?.url ?? '';
                if (url.isEmpty) {
                  showQyxNotice('No page loaded yet');
                  return;
                }
                Clipboard.setData(ClipboardData(text: url));
                // showQyxNotice drives off rootNavigatorKey/scaffoldMessengerKey
                // directly, not context, so it doesn't care whether this popup
                // is still open or has already been popped — the
                // postFrameCallback-after-pop dance the two branches used to
                // need (waiting for the popup to close before reaching for the
                // ROOT scaffold's messenger) is no longer needed.
                if (desktopOverlay) Navigator.of(context).pop();
                showQyxNotice('URL copied to clipboard', kind: QyxToastKind.success);
              },
            ),

            ListTile(
              leading: Icon(Icons.open_in_browser,
                  color: appTextColor.withAlpha(179)),
              title:
                  Text('Open Externally', style: TextStyle(color: appTextColor)),
              onTap: () async {
                final navigator = Navigator.of(context, rootNavigator: true);
                final url = ref.read(tabsProvider).safeActiveTab?.url ?? '';
                if (url.isEmpty) {
                  showQyxNotice('No page loaded yet');
                  return;
                }
                final uri = Uri.tryParse(url);
                if (uri == null || !await canLaunchUrl(uri)) {
                  showQyxNotice('Could not open this URL', kind: QyxToastKind.error);
                  return;
                }
                await launchUrl(uri, mode: LaunchMode.externalApplication);
                if (desktopOverlay && navigator.context.mounted) {
                  navigator.pop();
                }
              },
            ),

            ListTile(
              leading:
                  Icon(Icons.save_alt, color: appTextColor.withAlpha(179)),
              title: Text('Save Page', style: TextStyle(color: appTextColor)),
              onTap: () async {
                final rootNav = Navigator.of(context, rootNavigator: true);
                final engine = ref.read(activeBrowserEngineProvider);
                if (engine == null) {
                  showQyxNotice('No page loaded yet');
                  return;
                }
                final url = ref.read(tabsProvider).safeActiveTab?.url ?? '';
                final html = await engine.getPageHtml();

                final host =
                    (Uri.tryParse(url)?.host ?? 'page').replaceAll('.', '_');
                final filename =
                    '${host}_${DateTime.now().millisecondsSinceEpoch}.html';
                final savedPath = await ref
                    .read(downloadsProvider.notifier)
                    .savePage(html, filename);
                if (!context.mounted) return;
                if (savedPath != null) {
                  if (desktopOverlay) rootNav.pop();
                  showQyxNotice('Saved: $filename', kind: QyxToastKind.success);
                }
              },
            ),

            Divider(color: appTextColor.withAlpha(51)),

            // â”€â”€ SECURITY â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _sectionLabel(
                "SECURITY PROTOCOLS",
                isGhost ? Colors.redAccent : Colors.greenAccent),

            ListTile(
              title: Text(
                "New Ghost Tab",
                style: TextStyle(color: appTextColor),
              ),
              subtitle: Text(
                "Start a private session",
                style: TextStyle(
                    color: appTextColor.withAlpha(128), fontSize: 12),
              ),
              leading: Icon(Icons.privacy_tip_outlined,
                  color: appTextColor.withAlpha(179)),
              onTap: () {
                if (isDesktop) {
                  openMiraPrivateBrowserWindow(ref);
                  Navigator.pop(context);
                } else {
                  miraHaptic(MainScreenHapticKind.medium);
                  ref.read(ghostTabsProvider.notifier).addTab();
                  ref.read(isGhostModeProvider.notifier).state = true;
                  Navigator.pop(context);
                }
              },
            ),

            ListTile(
              title: const Text("Nuke Data",
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold)),
              leading:
                  const Icon(Icons.delete_forever, color: Colors.redAccent),
              onTap: () async {
                miraHaptic(MainScreenHapticKind.selection);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: theme.surfaceColor,
                    title: Text("Nuke Everything?",
                        style: TextStyle(color: appTextColor)),
                    content: Text(
                      "This will wipe all history, cookies, cache, and close all tabs. This cannot be undone.",
                      style: TextStyle(color: appTextColor.withAlpha(179)),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text("Cancel",
                              style: TextStyle(
                                  color: appTextColor.withAlpha(128)))),
                      TextButton(
                          onPressed: () {
                            miraHaptic(MainScreenHapticKind.medium);
                            Navigator.pop(ctx, true);
                          },
                          child: const Text("NUKE IT",
                              style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold))),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  // Cookies and site storage are process-wide managers in
                  // flutter_inappwebview, so a single direct call clears them
                  // for every tab (normal + ghost) regardless of which
                  // engine, if any, is currently active. Calling these
                  // directly — rather than only via activeBrowserEngineProvider
                  // — means Nuke Data still fully wipes cookies/storage even
                  // if there's no active engine wired up at nuke time.
                  try {
                    await CookieManager.instance().deleteAllCookies();
                    await WebStorageManager.instance().deleteAllData();
                  } catch (e) {
                    debugPrint('MIRA: Nuke - failed clearing cookies/storage: $e');
                  }

                  // Unlike cookies/storage, the HTTP cache is per-engine
                  // (per native webview controller), so every currently
                  // instantiated tab's engine needs its own explicit
                  // clearCache() call. Reading browserEngineProvider(id) for
                  // a tab whose webview was never mounted (e.g. still
                  // hibernated) is safe: it only constructs the Dart wrapper,
                  // and clearCache() no-ops internally until a native
                  // controller is actually attached.
                  final allTabIds = <String>{
                    ...ref.read(tabsProvider).tabs.keys,
                    ...ref.read(ghostTabsProvider).tabs.keys,
                  };
                  for (final id in allTabIds) {
                    try {
                      await ref.read(browserEngineProvider(id)).clearCache();
                    } catch (e) {
                      debugPrint('MIRA: Nuke - failed clearing cache for tab $id: $e');
                    }
                  }

                  ref.read(historyProvider.notifier).clearHistory();
                  ref.read(browserChromeProvider.notifier).resetSessionChrome();
                  ref.read(tabsProvider.notifier).nuke();
                  ref.read(ghostTabsProvider.notifier).nuke();
                  ref.read(isGhostModeProvider.notifier).state = false;
                  ref.read(browserChromeProvider.notifier).setLoadingProgress(100);

                  final s = ref.read(tabsProvider);
                  final wakeTab = s.safeActiveTab;
                  if (wakeTab != null) {
                    ref
                        .read(hibernationProvider.notifier)
                        .wakeTab(wakeTab.id);
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    showQyxNotice('System Purged.', kind: QyxToastKind.error);
                  }
                }
              },
            ),

            SwitchListTile(
              title: Text("Location Lock",
                  style: TextStyle(color: appTextColor)),
              secondary: Icon(Icons.location_off,
                  color: securityState.isLocationBlocked
                      ? Colors.greenAccent
                      : appTextColor.withAlpha(128)),
              value: securityState.isLocationBlocked,
              activeThumbColor: Colors.greenAccent,
              onChanged: (val) =>
                  ref.read(securityProvider.notifier).toggleLocation(val),
            ),

            SwitchListTile(
              title:
                  Text("Sensor Lock", style: TextStyle(color: appTextColor)),
              secondary: Icon(Icons.mic_off,
                  color: securityState.isCameraBlocked
                      ? Colors.greenAccent
                      : appTextColor.withAlpha(128)),
              value: securityState.isCameraBlocked,
              activeThumbColor: Colors.greenAccent,
              onChanged: (val) =>
                  ref.read(securityProvider.notifier).toggleCamera(val),
            ),

            // Ad blocking rides on WebKit-style ContentBlockers, which the
            // plugin only implements on Android/iOS/macOS — on Windows/Linux
            // _buildContentBlockers() returns an empty list, so the toggle
            // blocks precisely nothing. Show it disabled and say so rather than
            // reporting "Active" while doing nothing (O-89).
            SwitchListTile(
              title: Text("Ad & Tracker Block",
                  style: TextStyle(
                      color: adBlockSupported
                          ? appTextColor
                          : appTextColor.withAlpha(97))),
              subtitle: Text(
                !adBlockSupported
                    ? "Not supported on desktop yet"
                    : securityState.isAdBlockEnabled
                        ? "Active"
                        : "Off",
                style: TextStyle(
                    color: appTextColor.withAlpha(128), fontSize: 12),
              ),
              secondary: Icon(Icons.shield_outlined,
                  color: adBlockSupported && securityState.isAdBlockEnabled
                      ? Colors.greenAccent
                      : appTextColor.withAlpha(128)),
              value: adBlockSupported && securityState.isAdBlockEnabled,
              activeThumbColor: Colors.greenAccent,
              onChanged: !adBlockSupported
                  ? null
                  : (val) =>
                      ref.read(securityProvider.notifier).toggleAdBlock(val),
            ),


            Divider(color: appTextColor.withAlpha(51)),

            _sectionLabel("CUSTOMIZATION", primaryAccent),

            if (!isDesktop)
              SwitchListTile(
                title: Text("Desktop Mode",
                    style: TextStyle(color: appTextColor)),
                secondary: Icon(Icons.desktop_windows,
                    color: securityState.isDesktopMode
                        ? Colors.blueAccent
                        : appTextColor.withAlpha(128)),
                value: securityState.isDesktopMode,
                activeThumbColor: Colors.blueAccent,
                onChanged: (val) =>
                    ref.read(securityProvider.notifier).toggleDesktop(val),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16.0, vertical: 8.0),
              child: _buildThemeSelector(context, ref, theme, appTextColor),
            ),

            if (isGhost)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    "Ghost mode â€” new visits are not saved to history",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.redAccent.withAlpha(128),
                        fontSize: 12),
                  ),
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 4),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold,
              letterSpacing: 1.2)),
    );
  }

  Widget _buildThemeSelector(BuildContext context, WidgetRef ref,
      MiraTheme themeData, Color textColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double buttonWidth = (constraints.maxWidth - 4) / 3;
        final primary = themeData.primaryColor;

        return FittedBox(
          fit: BoxFit.scaleDown,
          child: ToggleButtons(
            borderRadius: BorderRadius.circular(12.0),
            borderWidth: 1.5,
            borderColor: textColor.withAlpha(26),
            selectedBorderColor: primary,
            fillColor: primary.withAlpha(51),
            selectedColor: primary,
            color: textColor.withAlpha(153),
            constraints: BoxConstraints(minHeight: 45.0, minWidth: buttonWidth),
            isSelected: [
              themeData.mode == ThemeMode.light,
              themeData.mode == ThemeMode.dark,
              themeData.mode == ThemeMode.system,
            ],
            onPressed: (index) {
              const modes = [
                ThemeMode.light,
                ThemeMode.dark,
                ThemeMode.system
              ];
              ref.read(themeProvider.notifier).setMode(modes[index]);
            },
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Wrap(spacing: 6, children: const [
                  Icon(Icons.light_mode_outlined, size: 16),
                  Text("Light",
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12))
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Wrap(spacing: 6, children: const [
                  Icon(Icons.dark_mode_outlined, size: 16),
                  Text("Dark",
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12))
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Wrap(spacing: 6, children: const [
                  Icon(Icons.brightness_auto_outlined, size: 16),
                  Text("Auto",
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12))
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}


