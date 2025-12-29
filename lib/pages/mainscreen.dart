import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mira/model/ad_block_model.dart';
import 'package:mira/model/book_mark_model.dart';
import 'package:mira/model/download_model.dart';
import 'package:url_launcher/url_launcher.dart'; // REQUIRED FOR OS HANDLING

// Models & Providers
import 'package:mira/model/ghost_model.dart';
import 'package:mira/model/search_engine.dart';
import 'package:mira/model/security_model.dart'; 
import 'package:mira/model/tab_model.dart';

// UI Pages
import 'package:mira/pages/branding_screen.dart';
import 'package:mira/pages/history_screen.dart';
import 'package:mira/pages/settings_screen.dart';
import 'package:mira/pages/tab_screen.dart'; 
import 'package:mira/pages/downlaods_screen.dart'; 
import 'package:mira/pages/book_marks_screen.dart'; 

// Local Providers
final loadingProgressProvider = StateProvider<int>((ref) => 0);
final webViewControllerProvider = StateProvider<InAppWebViewController?>((ref) => null);

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
    
    // Watch Bookmarks
    final bookmarks = ref.watch(bookmarksProvider);
    final isBookmarked = bookmarks.any((b) => b.url == activeUrl);

    // 2. THEME LOGIC
    final backgroundColor = isGhost ? Colors.black : const Color(0xFF121212);
    final appBarColor = isGhost ? const Color(0xFF100000) : const Color(0xFF1E1E1E);
    final accentColor = isGhost ? Colors.redAccent : Colors.white;

    // 3. ADDRESS BAR CONTROLLER (Created here to handle selection logic)
    final textController = TextEditingController(text: activeUrl);
    // Default cursor position: End of text
    textController.selection = TextSelection.collapsed(offset: activeUrl.length);

    // 4. CALCULATE SECURITY ICON
    IconData securityIcon;
    Color securityColor;

    if (activeUrl.isEmpty) {
      securityIcon = isGhost ? Icons.privacy_tip : Icons.search;
      securityColor = isGhost ? Colors.redAccent : Colors.white54;
    } else if (activeUrl.startsWith("https://")) {
      securityIcon = Icons.lock;
      securityColor = Colors.greenAccent;
    } else {
      securityIcon = Icons.no_encryption;
      securityColor = Colors.redAccent;
    }

    // 5. SECURITY LISTENER
    ref.listen(securityProvider, (previous, next) async {
      if (activeUrl.isEmpty) return; 

      final controller = ref.read(webViewControllerProvider);
      if (controller == null) return;

      if (previous?.isDesktopMode != next.isDesktopMode || 
          previous?.isAdBlockEnabled != next.isAdBlockEnabled) {
        try {
          await controller.setSettings(
            settings: InAppWebViewSettings(
              preferredContentMode: next.isDesktopMode 
                  ? UserPreferredContentMode.DESKTOP 
                  : UserPreferredContentMode.MOBILE,
              userAgent: next.isDesktopMode 
                  ? "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" 
                  : "",
              contentBlockers: next.isAdBlockEnabled ? AdBlockService.adBlockRules : [],
            ),
          );
          controller.reload();
        } catch (e) {
          debugPrint("Safe fail: Controller detached. $e");
        }
      }
    });

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final controller = ref.read(webViewControllerProvider);
        if (controller != null) {
          try {
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
          } catch (e) {
             if (isGhost) {
               ref.read(ghostTabsProvider.notifier).updateUrl('');
             } else {
               ref.read(tabsProvider.notifier).updateUrl('');
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
          
          leading: IconButton(
            icon: Icon(securityIcon, color: securityColor),
            onPressed: () {
              if (activeUrl.isNotEmpty) {
                showDialog(
                  context: context, 
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF2C2C2C),
                    title: Text(
                      activeUrl.startsWith("https://") ? "Connection Secure" : "Connection Not Secure",
                      style: TextStyle(color: securityColor),
                    ),
                    content: Text(
                      activeUrl.startsWith("https://") 
                        ? "MIRA verified this site uses a valid SSL certificate."
                        : "This site uses HTTP. Your data is not encrypted.",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Got it"))],
                  )
                );
              }
            },
          ),

          title: TextField(
            controller: textController,
            decoration: InputDecoration(
              hintText: isGhost ? 'Ghost Mode Active' : 'Search or enter address',
              border: InputBorder.none,
              hintStyle: TextStyle(color: isGhost ? Colors.red.withOpacity(0.3) : Colors.white30),
              
              suffixIcon: activeUrl.isNotEmpty && !isGhost
                  ? IconButton(
                      icon: Icon(
                        isBookmarked ? Icons.star : Icons.star_border,
                        color: isBookmarked ? Colors.yellowAccent : Colors.white30,
                        size: 20,
                      ),
                      onPressed: () {
                         ref.read(bookmarksProvider.notifier).toggleBookmark(activeUrl, activeTab.title);
                      },
                    )
                  : null,
            ),
            style: TextStyle(color: accentColor),
            textInputAction: TextInputAction.go,
            
            // --- FEATURE: SELECT ALL ON TAP ---
            onTap: () {
              textController.selection = TextSelection(
                baseOffset: 0,
                extentOffset: textController.text.length,
              );
            },
            
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

        body: activeUrl.isEmpty 
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
                contentBlockers: securityState.isAdBlockEnabled ? AdBlockService.adBlockRules : [],
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
              
              // --- FEATURE: DEEP LINKING (OS Handling) ---
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final uri = navigationAction.request.url;
                if (uri == null) return NavigationActionPolicy.ALLOW;

                final url = uri.toString();
                
                // 1. Allow HTTP/HTTPS to load in WebView
                if (uri.scheme == 'http' || uri.scheme == 'https') {
                  return NavigationActionPolicy.ALLOW;
                }

                // 2. Handle System Links (Mail, Tel, SMS)
                if (['mailto', 'tel', 'sms'].contains(uri.scheme)) {
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                    return NavigationActionPolicy.CANCEL;
                  }
                }

                // 3. Handle App Intents (Maps, WhatsApp, etc.)
                try {
                  // LaunchMode.externalApplication asks Android to open the default app
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                  return NavigationActionPolicy.CANCEL;
                } catch (e) {
                  // Fallback: If no app can handle it, do nothing or show toast
                  return NavigationActionPolicy.CANCEL; 
                }
              },

              onDownloadStartRequest: (controller, downloadRequest) async {
                  await DownloadManager.download(
                      downloadRequest.url.toString(),
                      filename: downloadRequest.suggestedFilename
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Downloading ${downloadRequest.suggestedFilename ?? 'file'}..."),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
              },
              // Permission handlers remain the same...
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
      ),
    );
  }

  // _buildDrawer remains unchanged from the previous robust version...
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
          
          ListTile(
            leading: Icon(Icons.history, color: isGhost ? Colors.white24 : Colors.white70),
            title: Text('History', style: TextStyle(color: isGhost ? Colors.white24 : Colors.white)),
            enabled: !isGhost,
            onTap: isGhost ? null : () {
              Navigator.pop(context); 
              Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryPage()));
            },
          ),

          ListTile(
            leading: const Icon(Icons.bookmark_border, color: Colors.white70),
            title: const Text('Bookmarks', style: TextStyle(color: Colors.white)),
            enabled: !isGhost,
            onTap: isGhost ? null : () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const BookmarksPage()));
            },
          ),

          ListTile(
            leading: const Icon(Icons.download, color: Colors.white70),
            title: const Text('Downloads', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const DownloadsPage()));
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

          const Divider(color: Colors.white24),

          Padding(
            padding: const EdgeInsets.only(left: 16, top: 10, bottom: 5),
            child: Text("SECURITY PROTOCOLS", style: TextStyle(color: isGhost ? Colors.redAccent : Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
          ),

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

          ListTile(
            title: const Text("Nuke Data", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF2C2C2C),
                  title: const Text("Nuke Everything?", style: TextStyle(color: Colors.white)),
                  content: const Text("This will wipe all history, cookies, cache, and close all tabs. This cannot be undone.", style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("NUKE IT", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                  ],
                ),
              );

              if (confirm == true) {
                await InAppWebViewController.clearAllCache();
                final cookieManager = CookieManager.instance();
                await cookieManager.deleteAllCookies();
                ref.read(historyProvider.notifier).clearHistory();
                ref.read(tabsProvider.notifier).nuke();
                ref.read(ghostTabsProvider.notifier).nuke();

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
            title: const Text("Location Lock", style: TextStyle(color: Colors.white)),
            secondary: Icon(Icons.location_off, color: securityState.isLocationBlocked ? Colors.greenAccent : Colors.white54),
            value: securityState.isLocationBlocked,
            activeColor: Colors.greenAccent,
            onChanged: (val) => ref.read(securityProvider.notifier).toggleLocation(val),
          ),

          SwitchListTile(
            title: const Text("Sensor Lock", style: TextStyle(color: Colors.white)),
            secondary: Icon(Icons.mic_off, color: securityState.isCameraBlocked ? Colors.greenAccent : Colors.white54),
            value: securityState.isCameraBlocked,
            activeColor: Colors.greenAccent,
            onChanged: (val) => ref.read(securityProvider.notifier).toggleCamera(val),
          ),
          
          SwitchListTile(
            title: const Text("The Shield", style: TextStyle(color: Colors.white)),
            secondary: Icon(Icons.shield, color: securityState.isAdBlockEnabled ? Colors.greenAccent : Colors.white54),
            value: securityState.isAdBlockEnabled,
            activeColor: Colors.greenAccent,
            onChanged: (val) {
               ref.read(securityProvider.notifier).toggleAdBlock(val);
            },
          ),

          const Divider(color: Colors.white24),

          Padding(
            padding: const EdgeInsets.only(left: 16, top: 10, bottom: 5),
            child: Text("CUSTOMIZATION", style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
          ),

          SwitchListTile(
            title: const Text("Desktop Mode", style: TextStyle(color: Colors.white)),
            secondary: Icon(Icons.desktop_windows, color: securityState.isDesktopMode ? Colors.blueAccent : Colors.white54),
            value: securityState.isDesktopMode,
            activeColor: Colors.blueAccent,
            onChanged: (val) {
               ref.read(securityProvider.notifier).toggleDesktop(val);
            },
          ),
        ],
      ),
    );
  }
}