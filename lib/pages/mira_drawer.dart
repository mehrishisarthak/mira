import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mira/model/search_engine.dart';

// Models
import 'package:mira/model/theme_model.dart';
import 'package:mira/model/security_model.dart';
import 'package:mira/model/ghost_model.dart';
import 'package:mira/model/tab_model.dart';
// Note: Ensure historyProvider is exported from history_screen or separate model file
import 'package:mira/pages/history_screen.dart'; 
import 'package:mira/pages/book_marks_screen.dart';
import 'package:mira/pages/downloads_screen.dart';
import 'package:mira/pages/browser_sheet.dart';

// [CRITICAL IMPORT] Import MainScreen to access the global providers 
// (webViewControllerProvider, webErrorProvider)
import 'package:mira/pages/mainscreen.dart'; 

class MiraDrawer extends ConsumerWidget {
  const MiraDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final securityState = ref.watch(securityProvider);
    final isGhost = ref.watch(isGhostModeProvider);
    final theme = ref.watch(themeProvider);
    
    // Determine text color based on background
    final isLight = theme.mode == ThemeMode.light;
    final appTextColor = isLight ? Colors.black87 : Colors.white;

    return Drawer(
      backgroundColor: theme.surfaceColor,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- BRANDING HEADER ---
                  Container(
                    height: 200, 
                    width: double.infinity,
                    decoration: BoxDecoration(color: isGhost ? const Color(0xFF100000) : theme.backgroundColor),
                    child: Center(
                      child: Text(
                        'M I R A',
                        style: GoogleFonts.jetBrainsMono(
                          color: isGhost ? Colors.redAccent : theme.primaryColor, 
                          fontSize: 24, 
                          letterSpacing: 5, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                  ),
                  
                  // --- NAVIGATION ITEMS ---
                  ListTile(
                    leading: Icon(Icons.history, color: appTextColor.withAlpha(179)),
                    title: Text('History', style: TextStyle(color: appTextColor)),
                    enabled: !isGhost,
                    onTap: isGhost ? null : () {
                      Navigator.pop(context); 
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryPage()));
                    },
                  ),

                  ListTile(
                    leading: Icon(Icons.bookmark_border, color: appTextColor.withAlpha(179)),
                    title: Text('Bookmarks', style: TextStyle(color: appTextColor)),
                    enabled: !isGhost,
                    onTap: isGhost ? null : () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const BookmarksPage()));
                    },
                  ),

                  ListTile(
                    leading: Icon(Icons.download, color: appTextColor.withAlpha(179)),
                    title: Text('Downloads', style: TextStyle(color: appTextColor)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const DownloadsPage()));
                    },
                  ),

                  ListTile(
                    leading: Icon(Icons.search, color: appTextColor.withAlpha(179)),
                    title: Text('Browser', style: TextStyle(color: appTextColor)),
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const BrowserSheet(),
                      );
                    },
                  ),

                  Divider(color: appTextColor.withAlpha(51)),

                  // --- SECURITY SECTION ---
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 10, bottom: 5),
                    child: Text("SECURITY PROTOCOLS", style: TextStyle(color: isGhost ? Colors.redAccent : Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),

                  ListTile(
                    title: Text("New Ghost Tab", style: TextStyle(color: appTextColor)),
                    subtitle: Text("Start a private session", style: TextStyle(color: appTextColor.withAlpha(128), fontSize: 12)),
                    leading: Icon(Icons.privacy_tip_outlined, color: appTextColor.withAlpha(179)),
                    onTap: () {
                        HapticFeedback.mediumImpact(); 
                        ref.read(isGhostModeProvider.notifier).state = true;
                        ref.read(ghostTabsProvider.notifier).addTab();
                        Navigator.pop(context);
                    },
                  ),

                  ListTile(
                    title: const Text("Nuke Data", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                    onTap: () async {
                      HapticFeedback.selectionClick(); 
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: theme.surfaceColor,
                          title: Text("Nuke Everything?", style: TextStyle(color: appTextColor)), 
                          content: Text("This will wipe all history, cookies, cache, and close all tabs. This cannot be undone.", style: TextStyle(color: appTextColor.withAlpha(179))),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("Cancel", style: TextStyle(color: appTextColor.withAlpha(128)))),
                            TextButton(onPressed: () {
                                HapticFeedback.heavyImpact(); 
                                Navigator.pop(ctx, true);
                            }, child: const Text("NUKE IT", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        // 1. Native Clear
                        await InAppWebViewController.clearAllCache();
                        final cookieManager = CookieManager.instance();
                        await cookieManager.deleteAllCookies();
                        
                        // 2. State Clear (Using providers from mainscreen.dart and models)
                        ref.read(historyProvider.notifier).clearHistory();
                        ref.read(webViewControllerProvider.notifier).state = null;
                        
                        ref.read(tabsProvider.notifier).nuke();
                        ref.read(ghostTabsProvider.notifier).nuke();
                        ref.read(webErrorProvider.notifier).state = null; 

                        // 3. Feedback
                        if (context.mounted) {
                           Navigator.pop(context); 
                           ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(content: Text("System Purged."), backgroundColor: Colors.redAccent),
                           );
                        }
                      }
                    },
                  ),

                  SwitchListTile(
                    title: Text("Location Lock", style: TextStyle(color: appTextColor)),
                    secondary: Icon(Icons.location_off, color: securityState.isLocationBlocked ? Colors.greenAccent : appTextColor.withAlpha(128)),
                    value: securityState.isLocationBlocked,
                    activeColor: Colors.greenAccent,
                    onChanged: (val) => ref.read(securityProvider.notifier).toggleLocation(val),
                  ),

                  SwitchListTile(
                    title: Text("Sensor Lock", style: TextStyle(color: appTextColor)),
                    secondary: Icon(Icons.mic_off, color: securityState.isCameraBlocked ? Colors.greenAccent : appTextColor.withAlpha(128)),
                    value: securityState.isCameraBlocked,
                    activeColor: Colors.greenAccent,
                    onChanged: (val) => ref.read(securityProvider.notifier).toggleCamera(val),
                  ),
                  
                  SwitchListTile(
                    title: Text("The Shield", style: TextStyle(color: appTextColor)),
                    secondary: Icon(Icons.shield, color: securityState.isAdBlockEnabled ? Colors.greenAccent : appTextColor.withAlpha(128)),
                    value: securityState.isAdBlockEnabled,
                    activeColor: Colors.greenAccent,
                    onChanged: (val) {
                        ref.read(securityProvider.notifier).toggleAdBlock(val);
                    },
                  ),

                  Divider(color: appTextColor.withAlpha(51)),

                  // --- CUSTOMIZATION SECTION ---
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 10, bottom: 5),
                    child: Text("CUSTOMIZATION", style: TextStyle(color: theme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),

                  SwitchListTile(
                    title: Text("Desktop Mode", style: TextStyle(color: appTextColor)),
                    secondary: Icon(Icons.desktop_windows, color: securityState.isDesktopMode ? Colors.blueAccent : appTextColor.withAlpha(128)),
                    value: securityState.isDesktopMode,
                    activeColor: Colors.blueAccent,
                    onChanged: (val) {
                        ref.read(securityProvider.notifier).toggleDesktop(val);
                    },
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: _buildDrawerThemeSelector(context, ref, theme, appTextColor),
                  ),
                  
                  if (isGhost)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(child: Text("Ghost Mode Active - History Disabled", style: TextStyle(color: Colors.redAccent.withAlpha(128), fontSize: 12))),
                    ),

                  const SizedBox(height: 100), 
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerThemeSelector(BuildContext context, WidgetRef ref, MiraTheme themeData, Color textColor) {
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
            constraints: BoxConstraints(
              minHeight: 45.0,
              minWidth: buttonWidth, 
            ),
            isSelected: [
              themeData.mode == ThemeMode.light,
              themeData.mode == ThemeMode.dark,
              themeData.mode == ThemeMode.system,
            ],
            onPressed: (index) {
              const List<ThemeMode> modes = [ThemeMode.light, ThemeMode.dark, ThemeMode.system];
              ref.read(themeProvider.notifier).setMode(modes[index]);
            },
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Wrap(spacing: 6, children: const [Icon(Icons.light_mode_outlined, size: 16), Text("Light", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Wrap(spacing: 6, children: const [Icon(Icons.dark_mode_outlined, size: 16), Text("Dark", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Wrap(spacing: 6, children: const [Icon(Icons.brightness_auto_outlined, size: 16), Text("Auto", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))]),
              ),
            ],
          ),
        );
      },
    );
  }
}