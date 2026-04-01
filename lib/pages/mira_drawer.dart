import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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

// Access global providers (webViewControllerProvider, webErrorProvider)
import 'package:mira/pages/mainscreen.dart';

/// Full-page replacement for the old end-drawer.
/// Opened via Navigator.push so it sits on the back stack — no swipe-to-open
/// gesture means the Android back-swipe no longer accidentally triggers it.
class MiraMenuPage extends ConsumerWidget {
  const MiraMenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final securityState = ref.watch(securityProvider);
    final isGhost = ref.watch(isGhostModeProvider);
    final theme = ref.watch(themeProvider);

    final isLight = theme.mode == ThemeMode.light;
    final appTextColor = isLight ? Colors.black87 : Colors.white;
    final primaryAccent = isGhost ? Colors.redAccent : theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.surfaceColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: appTextColor),
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
              enabled: !isGhost,
              onTap: isGhost
                  ? null
                  : () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const HistoryPage()),
                      ),
            ),

            ListTile(
              leading:
                  Icon(Icons.bookmark_border, color: appTextColor.withAlpha(179)),
              title: Text('Bookmarks', style: TextStyle(color: appTextColor)),
              enabled: !isGhost,
              onTap: isGhost
                  ? null
                  : () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const BookmarksPage()),
                      ),
            ),

            ListTile(
              leading:
                  Icon(Icons.download, color: appTextColor.withAlpha(179)),
              title: Text('Downloads', style: TextStyle(color: appTextColor)),
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const DownloadsPage()),
              ),
            ),

            ListTile(
              leading: Icon(Icons.search, color: appTextColor.withAlpha(179)),
              title: Text('Search Engine',
                  style: TextStyle(color: appTextColor)),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const BrowserSheet(),
                );
              },
            ),

            Divider(color: appTextColor.withAlpha(51)),

            // ── PAGE ACTIONS ────────────────────────────────────────────────
            _sectionLabel("PAGE ACTIONS", primaryAccent),

            ListTile(
              leading: Icon(Icons.link, color: appTextColor.withAlpha(179)),
              title: Text('Copy URL', style: TextStyle(color: appTextColor)),
              onTap: () {
                final url = ref.read(currentActiveTabProvider).url;
                if (url.isEmpty) return;
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('URL copied to clipboard')),
                );
              },
            ),

            ListTile(
              leading: Icon(Icons.open_in_browser,
                  color: appTextColor.withAlpha(179)),
              title:
                  Text('Open Externally', style: TextStyle(color: appTextColor)),
              onTap: () async {
                final url = ref.read(currentActiveTabProvider).url;
                if (url.isEmpty) return;
                final uri = Uri.tryParse(url);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),

            ListTile(
              leading:
                  Icon(Icons.save_alt, color: appTextColor.withAlpha(179)),
              title: Text('Save Page', style: TextStyle(color: appTextColor)),
              onTap: () async {
                final controller = ref.read(webViewControllerProvider);
                if (controller == null) return;
                final url = ref.read(currentActiveTabProvider).url;
                final html = await controller.getHtml();
                if (html == null) return;
                final host =
                    (Uri.tryParse(url)?.host ?? 'page').replaceAll('.', '_');
                final filename =
                    '${host}_${DateTime.now().millisecondsSinceEpoch}.html';
                final savedPath = await ref
                    .read(downloadsProvider.notifier)
                    .savePage(html, filename);
                if (context.mounted && savedPath != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Saved: $filename')),
                  );
                }
              },
            ),

            Divider(color: appTextColor.withAlpha(51)),

            // ── SECURITY ────────────────────────────────────────────────────
            _sectionLabel(
                "SECURITY PROTOCOLS",
                isGhost ? Colors.redAccent : Colors.greenAccent),

            ListTile(
              title: Text("New Ghost Tab",
                  style: TextStyle(color: appTextColor)),
              subtitle: Text("Start a private session",
                  style: TextStyle(
                      color: appTextColor.withAlpha(128), fontSize: 12)),
              leading: Icon(Icons.privacy_tip_outlined,
                  color: appTextColor.withAlpha(179)),
              onTap: () {
                HapticFeedback.mediumImpact();
                ref.read(isGhostModeProvider.notifier).state = true;
                ref.read(ghostTabsProvider.notifier).addTab();
                Navigator.pop(context);
              },
            ),

            ListTile(
              title: const Text("Nuke Data",
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold)),
              leading:
                  const Icon(Icons.delete_forever, color: Colors.redAccent),
              onTap: () async {
                HapticFeedback.selectionClick();
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
                            HapticFeedback.heavyImpact();
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
                  await InAppWebViewController.clearAllCache();
                  final cookieManager = CookieManager.instance();
                  await cookieManager.deleteAllCookies();

                  ref.read(historyProvider.notifier).clearHistory();
                  ref.read(webViewControllerProvider.notifier).state = null;
                  ref.read(tabsProvider.notifier).nuke();
                  ref.read(ghostTabsProvider.notifier).nuke();
                  ref.read(webErrorProvider.notifier).state = null;

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
              title:
                  Text("The Shield", style: TextStyle(color: appTextColor)),
              secondary: Icon(Icons.shield,
                  color: securityState.isAdBlockEnabled
                      ? Colors.greenAccent
                      : appTextColor.withAlpha(128)),
              value: securityState.isAdBlockEnabled,
              activeThumbColor: Colors.greenAccent,
              onChanged: (val) =>
                  ref.read(securityProvider.notifier).toggleAdBlock(val),
            ),

            // ── PROXY ──────────────────────────────────────────────────────
            SwitchListTile(
              title: Text("Network Proxy",
                  style: TextStyle(color: appTextColor)),
              secondary: Icon(Icons.router,
                  color: securityState.isProxyEnabled
                      ? Colors.orangeAccent
                      : appTextColor.withAlpha(128)),
              subtitle: Text(
                securityState.proxyUrl.isEmpty
                    ? "No Proxy Set"
                    : securityState.proxyUrl,
                style: TextStyle(
                    color: appTextColor.withAlpha(128), fontSize: 11),
              ),
              value: securityState.isProxyEnabled,
              activeThumbColor: Colors.orangeAccent,
              onChanged: (val) =>
                  ref.read(securityProvider.notifier).toggleProxy(val),
            ),

            if (securityState.isProxyEnabled)
              ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.only(left: 72, right: 16),
                title: Text("Configure Proxy",
                    style: TextStyle(
                        color: theme.primaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
                onTap: () async {
                  final controller =
                      TextEditingController(text: securityState.proxyUrl);
                  final newUrl = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: theme.surfaceColor,
                      title: Text("Proxy Configuration",
                          style: TextStyle(color: appTextColor)),
                      content: TextField(
                        controller: controller,
                        autofocus: true,
                        style: TextStyle(color: appTextColor),
                        decoration: InputDecoration(
                          hintText: "http://your-proxy:port",
                          hintStyle:
                              TextStyle(color: appTextColor.withAlpha(80)),
                          enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color:
                                      theme.primaryColor.withAlpha(100))),
                          focusedBorder: UnderlineInputBorder(
                              borderSide:
                                  BorderSide(color: theme.primaryColor)),
                        ),
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text("Cancel",
                                style: TextStyle(
                                    color: appTextColor.withAlpha(128)))),
                        TextButton(
                            onPressed: () =>
                                Navigator.pop(ctx, controller.text),
                            child: Text("Save",
                                style: TextStyle(
                                    color: theme.primaryColor,
                                    fontWeight: FontWeight.bold))),
                      ],
                    ),
                  );
                  if (newUrl != null) {
                    ref
                        .read(securityProvider.notifier)
                        .updateProxyUrl(newUrl);
                  }
                },
              ),

            Divider(color: appTextColor.withAlpha(51)),

            // ── CUSTOMIZATION ───────────────────────────────────────────────
            _sectionLabel("CUSTOMIZATION", primaryAccent),

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
                    "Ghost Mode Active — History Disabled",
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

  // ── HELPERS ──────────────────────────────────────────────────────────────

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




