import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/pages/main_screen/main_screen_haptics.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mira/core/notifiers/history_notifier.dart';

// Models
import 'package:mira/core/entities/theme_entity.dart';
import 'package:mira/core/notifiers/theme_notifier.dart';
import 'package:mira/core/notifiers/security_notifier.dart';
import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/core/services/download_provider.dart';
import 'package:mira/pages/history_screen.dart';
import 'package:mira/pages/book_marks_screen.dart';
import 'package:mira/pages/downloads_screen.dart';
import 'package:mira/pages/browser_sheet.dart';

import 'package:mira/pages/browser_chrome_providers.dart';
import 'package:mira/core/notifiers/hibernation_notifier.dart';
import 'package:mira/shell/desktop/open_private_browser_window.dart';

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

    final isLight = theme.mode == ThemeMode.light;
    final appTextColor = isLight ? kMiraInkPrimary : Colors.white;
    final primaryAccent = isGhost ? Colors.redAccent : theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.surfaceColor,
        leading: IconButton(
          icon: Icon(
            desktopOverlay ? Icons.close : Icons.arrow_back,
            color: appTextColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'M I R A',
          style: GoogleFonts.jetBrainsMono(
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

            // ── NAVIGATION ──────────────────────────────────────────────────
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

            // ── PAGE ACTIONS ────────────────────────────────────────────────
            _sectionLabel("PAGE ACTIONS", primaryAccent),

            ListTile(
              leading: Icon(Icons.link, color: appTextColor.withAlpha(179)),
              title: Text('Copy URL', style: TextStyle(color: appTextColor)),
              onTap: () {
                final rootNav = Navigator.of(context, rootNavigator: true);
                final url = ref.read(currentActiveTabProvider).url;
                if (url.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No page loaded yet')),
                  );
                  return;
                }
                Clipboard.setData(ClipboardData(text: url));
                if (desktopOverlay) {
                  Navigator.of(context).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (rootNav.context.mounted) {
                      ScaffoldMessenger.of(rootNav.context).showSnackBar(
                        const SnackBar(
                            content: Text('URL copied to clipboard')),
                      );
                    }
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('URL copied to clipboard')),
                  );
                }
              },
            ),

            ListTile(
              leading: Icon(Icons.open_in_browser,
                  color: appTextColor.withAlpha(179)),
              title:
                  Text('Open Externally', style: TextStyle(color: appTextColor)),
              onTap: () async {
                final navigator = Navigator.of(context, rootNavigator: true);
                final messenger = ScaffoldMessenger.of(context);
                final url = ref.read(currentActiveTabProvider).url;
                if (url.isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('No page loaded yet')),
                  );
                  return;
                }
                final uri = Uri.tryParse(url);
                if (uri == null || !await canLaunchUrl(uri)) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Could not open this URL')),
                  );
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No page loaded yet')),
                  );
                  return;
                }
                final url = ref.read(currentActiveTabProvider).url;
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
                  if (desktopOverlay) {
                    rootNav.pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (rootNav.context.mounted) {
                        ScaffoldMessenger.of(rootNav.context).showSnackBar(
                          SnackBar(content: Text('Saved: $filename')),
                        );
                      }
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Saved: $filename')),
                    );
                  }
                }
              },
            ),

            Divider(color: appTextColor.withAlpha(51)),

            // ── SECURITY ────────────────────────────────────────────────────
            _sectionLabel(
                "SECURITY PROTOCOLS",
                isGhost ? Colors.redAccent : Colors.greenAccent),

            ListTile(
              title: Text(
                isDesktop ? "New private window" : "New Ghost Tab",
                style: TextStyle(color: appTextColor),
              ),
              subtitle: Text(
                isDesktop
                    ? "Opens a separate private window (like Chrome)"
                    : "Start a private session",
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
                  final engine = ref.read(activeBrowserEngineProvider);
                  if (engine != null) {
                    await engine.clearStorage();
                    await engine.clearCookies();
                  }

                  ref.read(historyProvider.notifier).clearHistory();
                  ref.read(browserChromeProvider.notifier).resetSessionChrome();
                  ref.read(tabsProvider.notifier).nuke();
                  ref.read(ghostTabsProvider.notifier).nuke();
                  ref.read(isGhostModeProvider.notifier).state = false;
                  ref.read(browserChromeProvider.notifier).setLoadingProgress(100);

                  final s = ref.read(tabsProvider);
                  if (s.tabs.isNotEmpty) {
                    ref
                        .read(hibernationProvider.notifier)
                        .wakeTab(s.tabs[s.activeIndex].id);
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("System Purged."),
                          backgroundColor: Colors.redAccent),
                    );
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

            SwitchListTile(
              title: Text("Ad & Tracker Block",
                  style: TextStyle(color: appTextColor)),
              subtitle: Text(
                securityState.isAdBlockEnabled ? "Active" : "Off",
                style: TextStyle(
                    color: appTextColor.withAlpha(128), fontSize: 12),
              ),
              secondary: Icon(Icons.shield_outlined,
                  color: securityState.isAdBlockEnabled
                      ? Colors.greenAccent
                      : appTextColor.withAlpha(128)),
              value: securityState.isAdBlockEnabled,
              activeThumbColor: Colors.greenAccent,
              onChanged: (val) =>
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
                    "Ghost mode — new visits are not saved to history",
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
