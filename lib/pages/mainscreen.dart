import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

// Models & Providers
import 'package:mira/model/ghost_model.dart';
import 'package:mira/model/search_engine.dart';
import 'package:mira/model/security_model.dart'; 
import 'package:mira/model/tab_model.dart';
import 'package:mira/pages/fire_overlay.dart'; 

// UI Pages
import 'package:mira/pages/branding_screen.dart';
import 'package:mira/pages/history_screen.dart';
import 'package:mira/pages/settings_screen.dart';
import 'package:mira/pages/tab_screen.dart'; 

// Local Providers
final loadingProgressProvider = StateProvider<int>((ref) => 0);
final webViewControllerProvider = StateProvider<InAppWebViewController?>((ref) => null);
final isNukingProvider = StateProvider<bool>((ref) => false); 

class Mainscreen extends ConsumerWidget {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Mainscreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. WATCH STATE
    final isGhost = ref.watch(isGhostModeProvider);
    final activeTab = ref.watch(currentActiveTabProvider);
    final activeUrl = activeTab.url;
    final currentTabsList = ref.watch(currentTabListProvider);
    final tabCount = currentTabsList.length;
    final securityState = ref.watch(securityProvider);
    final double progress = ref.watch(loadingProgressProvider) / 100;
    
    // Watch Nuke State
    final isNuking = ref.watch(isNukingProvider);

    // 2. THEME LOGIC
    final backgroundColor = isGhost ? Colors.black : const Color(0xFF121212);
    final appBarColor = isGhost ? const Color(0xFF100000) : const Color(0xFF1E1E1E);
    final accentColor = isGhost ? Colors.redAccent : Colors.white;

    // 3. CRASH FIX: LISTENER
    ref.listen(securityProvider, (previous, next) async {
      final controller = ref.read(webViewControllerProvider);
      if (controller == null) return;

      if (previous?.isDesktopMode != next.isDesktopMode) {
        await controller.setSettings(
          settings: InAppWebViewSettings(
            preferredContentMode: next.isDesktopMode 
                ? UserPreferredContentMode.DESKTOP 
                : UserPreferredContentMode.MOBILE,
            userAgent: next.isDesktopMode 
                ? "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" 
                : "",
          ),
        );
        controller.reload();
      }
    });

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final controller = ref.read(webViewControllerProvider);
        if (controller != null) {
          if (await controller.canGoBack()) {
            controller.goBack();
          } else {
            if (activeUrl.isNotEmpty) {
               if (isGhost) {
                 ref.read(ghostTabsProvider.notifier).updateUrl('');
               } else {
                 ref.read(tabsProvider.notifier).updateUrl('');
               }
            }
          }
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: backgroundColor,
        endDrawer: _buildDrawer(context, ref, securityState, isGhost),
        
        appBar: AppBar(
          backgroundColor: appBarColor,
          titleSpacing: 0,
          leading: Icon(
            isGhost ? Icons.privacy_tip : Icons.search, 
            color: isGhost ? Colors.redAccent : Colors.white54
          ),
          title: TextField(
            decoration: InputDecoration(
              hintText: isGhost ? 'Ghost Mode Active' : 'Search or enter address',
              border: InputBorder.none,
              hintStyle: TextStyle(color: isGhost ? Colors.red.withOpacity(0.3) : Colors.white30),
            ),
            style: TextStyle(color: accentColor),
            textInputAction: TextInputAction.go,
            controller: TextEditingController(text: activeUrl)..selection = TextSelection.collapsed(offset: activeUrl.length),
            
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                 String finalUrl;
                 if (value.contains('.') && !value.contains(' ')) {
                    finalUrl = "https://$value";
                 } else {
                    finalUrl = ref.read(formattedSearchUrlProvider(value));
                 }
                 
                 if (isGhost) {
                    ref.read(ghostTabsProvider.notifier).updateUrl(finalUrl);
                 } else {
                    ref.read(historyProvider.notifier).addToHistory(value);
                    ref.read(tabsProvider.notifier).updateUrl(finalUrl);
                 }

                 ref.read(webViewControllerProvider)?.loadUrl(
                   urlRequest: URLRequest(url: WebUri(finalUrl))
                 );
              }
            },
          ),
          actions: [
            // --- TAB SWITCHER ---
            InkWell(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const FractionallySizedBox(
                    heightFactor: 0.8,
                    child: TabsSheet(), 
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: isGhost ? Colors.redAccent.withOpacity(0.5) : Colors.white24, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "$tabCount", 
                  style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            
            // --- MENU ---
            IconButton(
              icon: Icon(Icons.more_vert, color: accentColor),
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
          ],
          bottom: progress < 1.0 
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: progress, 
                  backgroundColor: Colors.transparent, 
                  color: isGhost ? Colors.redAccent : Colors.greenAccent
                ),
              ) 
            : null,
        ),

        // --- BODY STACK ---
        body: Stack(
          children: [
            // Layer 1: The Browser Content
            activeUrl.isEmpty 
              ? const BrandingScreen()
              : InAppWebView(
                  key: ValueKey("${isGhost ? 'G' : 'N'}_${activeTab.id}"),
                  initialUrlRequest: URLRequest(url: WebUri(activeUrl)),
                  initialSettings: InAppWebViewSettings(
                    incognito: isGhost || securityState.isIncognito, 
                    clearCache: isGhost || securityState.isIncognito,
                    useHybridComposition: true,
                    userAgent: securityState.isDesktopMode 
                        ? "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" 
                        : "",
                    preferredContentMode: securityState.isDesktopMode 
                        ? UserPreferredContentMode.DESKTOP 
                        : UserPreferredContentMode.MOBILE,
                  ),
                  onWebViewCreated: (controller) {
                    ref.read(webViewControllerProvider.notifier).state = controller;
                  },
                  onProgressChanged: (controller, progress) {
                    ref.read(loadingProgressProvider.notifier).state = progress;
                  },
                  onLoadStop: (controller, url) {
                     if (url != null) {
                       if (isGhost) {
                          ref.read(ghostTabsProvider.notifier).updateUrl(url.toString());
                       } else {
                          ref.read(tabsProvider.notifier).updateUrl(url.toString());
                       }
                     }
                  },
                  onTitleChanged: (controller, title) {
                     if (title != null) {
                       if (isGhost) {
                          ref.read(ghostTabsProvider.notifier).updateTitle(title);
                       } else {
                          ref.read(tabsProvider.notifier).updateTitle(title);
                       }
                     }
                  },
                  onPermissionRequest: (controller, request) async {
                    final resources = request.resources;
                    if (securityState.isLocationBlocked && resources.contains(PermissionResourceType.DEVICE_ORIENTATION_AND_MOTION)) {
                        return PermissionResponse(resources: resources, action: PermissionResponseAction.DENY);
                    }
                    if (securityState.isCameraBlocked) {
                      if (resources.contains(PermissionResourceType.CAMERA) || 
                          resources.contains(PermissionResourceType.MICROPHONE)) {
                        return PermissionResponse(resources: resources, action: PermissionResponseAction.DENY);
                      }
                    }
                    return PermissionResponse(resources: resources, action: PermissionResponseAction.DENY);
                  },
                  onGeolocationPermissionsShowPrompt: (controller, origin) async {
                     if (securityState.isLocationBlocked) {
                       return GeolocationPermissionShowPromptResponse(origin: origin, allow: false, retain: false);
                     }
                     return GeolocationPermissionShowPromptResponse(origin: origin, allow: true, retain: false);
                  },
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref, SecurityState securityState, bool isGhost) {
    return Drawer(
      backgroundColor: const Color(0xFF1E1E1E),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: isGhost ? const Color(0xFF100000) : const Color(0xFF121212)),
            child: Center(
              child: Text(
                'M I R A',
                style: TextStyle(
                  color: isGhost ? Colors.redAccent : Colors.white, 
                  fontSize: 24, 
                  letterSpacing: 5, 
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 10, bottom: 5),
            child: Text("SECURITY PROTOCOLS", style: TextStyle(color: isGhost ? Colors.redAccent : Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
          ),

          // GHOST MODE BUTTON
          ListTile(
            title: const Text("New Ghost Tab", style: TextStyle(color: Colors.white)),
            subtitle: const Text("Start a private session", style: TextStyle(color: Colors.white54, fontSize: 12)),
            leading: const Icon(Icons.privacy_tip_outlined, color: Colors.white70),
            onTap: () {
               ref.read(isGhostModeProvider.notifier).state = true;
               ref.read(ghostTabsProvider.notifier).addTab();
               Navigator.pop(context);
            },
          ),

          // NUKE BUTTON
          //TODO : replace nuke icon with radioactive icon
          ListTile(
            title: const Text("Nuke", style: TextStyle(color: Colors.white)),
            leading: const Icon(Icons.dangerous, color: Colors.redAccent),
            trailing: IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white70),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("What is Nuke?"),
                    content: const Text("Nuke clears all browsing data, including history, cache, and cookies. It also closes all tabs, giving you a fresh start."),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("OK"),
                      ),
                    ],
                  ),
                );
              },
            ),
            onTap: () async {
              // --- CLEANUP LOGIC ---
              // 1. Clear Web Cache & Cookies
              await InAppWebViewController.clearAllCache();
              final cookieManager = CookieManager.instance();
              await cookieManager.deleteAllCookies();

              // 2. Clear History
              ref.read(historyProvider.notifier).clearHistory();

              // 3. Nuke All Tabs
              ref.read(tabsProvider.notifier).nuke();
              ref.read(ghostTabsProvider.notifier).nuke();

              // 4. Show Snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("History and cache has been cleared."),
                  backgroundColor: Colors.green,
                ),
              );

              // 5. Close Drawer
              Navigator.pop(context);
            },
          ),

          // LOCATION LOCK
          SwitchListTile(
            title: const Text("Location Lock", style: TextStyle(color: Colors.white)),
            secondary: Icon(Icons.location_off, color: securityState.isLocationBlocked ? Colors.greenAccent : Colors.white54),
            value: securityState.isLocationBlocked,
            activeColor: Colors.greenAccent,
            onChanged: (val) => ref.read(securityProvider.notifier).toggleLocation(val),
          ),

          // SENSOR LOCK
          SwitchListTile(
            title: const Text("Sensor Lock", style: TextStyle(color: Colors.white)),
            secondary: Icon(Icons.mic_off, color: securityState.isCameraBlocked ? Colors.greenAccent : Colors.white54),
            value: securityState.isCameraBlocked,
            activeColor: Colors.greenAccent,
            onChanged: (val) => ref.read(securityProvider.notifier).toggleCamera(val),
          ),

          const Divider(color: Colors.white24),

          Padding(
            padding: const EdgeInsets.only(left: 16, top: 10, bottom: 5),
            child: Text("CUSTOMIZATION", style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
          ),

           // DESKTOP MODE
          SwitchListTile(
            title: const Text("Desktop Mode", style: TextStyle(color: Colors.white)),
            secondary: Icon(Icons.desktop_windows, color: securityState.isDesktopMode ? Colors.blueAccent : Colors.white54),
            value: securityState.isDesktopMode,
            activeColor: Colors.blueAccent,
            onChanged: (val) {
               ref.read(securityProvider.notifier).toggleDesktop(val);
            },
          ),

          const Divider(color: Colors.white24),

          // History
          ListTile(
            leading: Icon(Icons.history, color: isGhost ? Colors.white24 : Colors.white70),
            title: Text('History', style: TextStyle(color: isGhost ? Colors.white24 : Colors.white)),
            enabled: !isGhost,
            onTap: isGhost ? null : () {
              Navigator.pop(context); 
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryPage()),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.search, color: Colors.white70),
            title: const Text('Search Engine', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) => const SettingsSheet(),
              );
            },
          ),
        ],
      ),
    );
  }
}