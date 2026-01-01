import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Haptics
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart'; // --- [NEW] For Monospace Font ---
import 'package:mira/model/ad_block_model.dart';
import 'package:mira/model/book_mark_model.dart';
import 'package:mira/model/download_model.dart';
import 'package:mira/model/theme_model.dart';
import 'package:mira/pages/skelleton_loader.dart';
import 'package:url_launcher/url_launcher.dart'; 

// Models & Providers
import 'package:mira/model/ghost_model.dart';
import 'package:mira/model/search_engine.dart';
import 'package:mira/model/security_model.dart'; 
import 'package:mira/model/tab_model.dart';

// UI Pages
import 'package:mira/pages/branding_screen.dart';
import 'package:mira/pages/history_screen.dart';
import 'package:mira/pages/browser_sheet.dart'; 
import 'package:mira/pages/tab_screen.dart'; 
import 'package:mira/pages/downloads_screen.dart'; 
import 'package:mira/pages/book_marks_screen.dart'; 
import 'package:mira/pages/custom_error_screen.dart'; 

// Local Providers
final loadingProgressProvider = StateProvider<int>((ref) => 0);
final webViewControllerProvider = StateProvider<InAppWebViewController?>((ref) => null);
final webErrorProvider = StateProvider<String?>((ref) => null); 

class Mainscreen extends ConsumerStatefulWidget {
  const Mainscreen({super.key});

  @override
  ConsumerState<Mainscreen> createState() => _MainscreenState();
}

class _MainscreenState extends ConsumerState<Mainscreen> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // For Double-Tap to Exit logic
  DateTime? _lastExitTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (ref.read(webErrorProvider) != null) {
         debugPrint("System: App Resumed. Healing broken connection...");
         ref.read(webErrorProvider.notifier).state = null;
         final controller = ref.read(webViewControllerProvider);
         controller?.reload();
      }
    }
  }

  // Robust Search vs URL Detection
  bool _isValidUrl(String value) {
    if (value.contains(' ')) return false;
    if (value.startsWith('http://') || value.startsWith('https://')) return true;
    
    final domainRegExp = RegExp(
      r'^(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}|' 
      r'^localhost|' 
      r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$'
    );
    return domainRegExp.hasMatch(value);
  }

  void _handlePop() async {
    final controller = ref.read(webViewControllerProvider);
    final errorMessage = ref.read(webErrorProvider);
    final activeUrl = ref.read(currentActiveTabProvider).url;
    final isGhost = ref.read(isGhostModeProvider);
    final appTheme = ref.read(themeProvider);

    // 1. Handle Error Screen Back
    if (errorMessage != null) {
      if (await controller?.canGoBack() ?? false) {
        ref.read(webErrorProvider.notifier).state = null;
        controller?.goBack();
        return;
      }
    }

    // 2. Handle Browser Back
    if (controller != null && await controller.canGoBack()) {
      controller.goBack();
      return;
    }

    // 3. Handle Going to Home (Branding)
    if (activeUrl.isNotEmpty) {
      HapticFeedback.lightImpact(); // --- [TACTILE] Feedback on clearing URL ---
      if (isGhost) {
        ref.read(ghostTabsProvider.notifier).updateUrl('');
      } else {
        ref.read(tabsProvider.notifier).updateUrl('');
      }
      ref.read(webErrorProvider.notifier).state = null;
      return;
    }

    // 4. Double Tap to Exit
    final now = DateTime.now();
    if (_lastExitTime == null ||
        now.difference(_lastExitTime!) > const Duration(seconds: 2)) {
      _lastExitTime = now;
      if (mounted) {
        HapticFeedback.selectionClick(); // --- [TACTILE] Warning vibration ---
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Press back again to exit MIRA"),
              backgroundColor: isGhost ? Colors.redAccent : appTheme.primaryColor,
              duration: const Duration(seconds: 2),
            )
        );
      }
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. WATCH STATE
    final isGhost = ref.watch(isGhostModeProvider);
    final activeTab = ref.watch(currentActiveTabProvider);
    final activeUrl = activeTab.url;
    final currentTabsList = ref.watch(currentTabListProvider);
    final tabCount = currentTabsList.length;
    final securityState = ref.watch(securityProvider);
    final double progress = ref.watch(loadingProgressProvider) / 100;
    
    final errorMessage = ref.watch(webErrorProvider);
    final bookmarks = ref.watch(bookmarksProvider);
    final isBookmarked = bookmarks.any((b) => b.url == activeUrl);
    final appTheme = ref.watch(themeProvider);
    
    // 2. THEME & COLORS
    final backgroundColor = appTheme.backgroundColor;
    final appBarColor = appTheme.surfaceColor;
    final primaryAccent = isGhost ? Colors.redAccent : appTheme.primaryColor;
    
    final isLightMode = appTheme.mode == ThemeMode.light;
    final contentColor = isLightMode ? Colors.black87 : Colors.white;
    final hintColor = isLightMode ? Colors.black38 : Colors.white30;

    final textController = TextEditingController(text: activeUrl);
    textController.selection = TextSelection.collapsed(offset: activeUrl.length);

    IconData securityIcon;
    Color securityColor;

    if (activeUrl.isEmpty) {
      securityIcon = isGhost ? Icons.privacy_tip : Icons.search;
      securityColor = isGhost ? Colors.redAccent : hintColor;
    } else if (activeUrl.startsWith("https://")) {
      securityIcon = Icons.lock;
      securityColor = Colors.greenAccent;
    } else {
      securityIcon = Icons.no_encryption;
      securityColor = Colors.redAccent;
    }

    // --- LISTENERS ---

    // 1. Tab Switch -> Reset Progress & Controller
    ref.listen(currentActiveTabProvider, (previous, next) {
      if (previous?.id != next.id) {
        ref.read(loadingProgressProvider.notifier).state = 0;
        ref.read(webViewControllerProvider.notifier).state = null; 
      }
    });

    // 2. Smart Settings Updates
    ref.listen(themeProvider, (_, __) => _updateWebViewSettings(forceReload: false));
    
    ref.listen(securityProvider, (prev, next) {
      if (prev?.isDesktopMode != next.isDesktopMode || 
          prev?.isAdBlockEnabled != next.isAdBlockEnabled) {
        _updateWebViewSettings(forceReload: true);
      }
    });

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _handlePop();
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: backgroundColor,
        endDrawer: _buildDrawer(context, ref, securityState, isGhost, appTheme, contentColor),
        
        appBar: AppBar(
          backgroundColor: appBarColor,
          titleSpacing: 0,
          leading: IconButton(
            icon: Icon(securityIcon, color: securityColor),
            onPressed: () {
              if (activeUrl.isNotEmpty) {
                HapticFeedback.selectionClick(); // --- [TACTILE] ---
                showDialog(
                  context: context, 
                  builder: (ctx) => AlertDialog(
                    backgroundColor: appTheme.surfaceColor,
                    title: Text(
                      activeUrl.startsWith("https://") ? "Connection Secure" : "Connection Not Secure",
                      style: TextStyle(color: securityColor),
                    ),
                    content: Text(
                      activeUrl.startsWith("https://") 
                        ? "MIRA verified this site uses a valid SSL certificate."
                        : "This site uses HTTP. Your data is not encrypted.",
                      style: TextStyle(color: contentColor.withAlpha(179)),
                    ),
                    actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Got it"))],
                  )
                );
              }
            },
          ),

          title: TextField(
            controller: textController,
            // --- [FIXED] Restored 'jetBrainsMono' (Capital B is key) ---
            style: GoogleFonts.jetBrainsMono(
              color: contentColor,
              fontWeight: FontWeight.w500,
              fontSize: 14, 
            ), 
            cursorColor: primaryAccent,
            decoration: InputDecoration(
              hintText: isGhost ? 'Ghost Mode Active' : 'Search or enter address',
              border: InputBorder.none,
              // --- [FIXED] Restored 'jetBrainsMono' ---
              hintStyle: GoogleFonts.jetBrainsMono(color: hintColor), 
              suffixIcon: activeUrl.isNotEmpty && !isGhost
                  ? IconButton(
                      icon: Icon(
                        isBookmarked ? Icons.star : Icons.star_border,
                        color: isBookmarked ? Colors.yellowAccent : hintColor,
                        size: 20,
                      ),
                      onPressed: () {
                          HapticFeedback.selectionClick(); // --- [TACTILE] ---
                          ref.read(bookmarksProvider.notifier).toggleBookmark(activeUrl, activeTab.title);
                      },
                    )
                  : null,
            ),
            textInputAction: TextInputAction.go,
            onTap: () {
              textController.selection = TextSelection(baseOffset: 0, extentOffset: textController.text.length);
            },
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                 HapticFeedback.lightImpact(); // --- [TACTILE] Enter pressed ---
                 ref.read(webErrorProvider.notifier).state = null;

                 String finalUrl;
                 if (_isValidUrl(value)) {
                   finalUrl = value.startsWith("http") ? value : "https://$value";
                 } else {
                   finalUrl = ref.read(formattedSearchUrlProvider(value));
                 }
                 
                 if (isGhost) {
                   ref.read(ghostTabsProvider.notifier).updateUrl(finalUrl);
                 } else {
                   ref.read(historyProvider.notifier).addToHistory(value);
                   ref.read(tabsProvider.notifier).updateUrl(finalUrl);
                 }

                 final controller = ref.read(webViewControllerProvider);
                 if (controller != null) {
                   controller.loadUrl(
                     urlRequest: URLRequest(url: WebUri(finalUrl))
                   );
                 }
              }
            },
          ),
          actions: [
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick(); // --- [TACTILE] Click feel ---
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const FractionallySizedBox(heightFactor: 0.8, child: TabsSheet()),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryAccent, 
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "$tabCount", 
                  // --- [FIXED] Restored 'jetBrainsMono' ---
                  style: GoogleFonts.jetBrainsMono(
                    color: Colors.white,
                    fontWeight: FontWeight.bold
                  )
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.more_vert, color: contentColor),
              onPressed: () {
                HapticFeedback.selectionClick(); // --- [TACTILE] ---
                _scaffoldKey.currentState?.openEndDrawer();
              },
            ),
          ],
          
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: progress < 1.0 
              ? LinearProgressIndicator(
                  value: progress, 
                  backgroundColor: Colors.transparent, 
                  color: primaryAccent
                )
              : Container(height: 2, color: Colors.transparent),
          ),
        ),
        body: _buildBody(activeUrl, errorMessage, ref, securityState, isGhost, activeTab.id, primaryAccent, appTheme),
      ),
    );
  }

  Widget _buildBody(String activeUrl, String? errorMessage, WidgetRef ref, SecurityState securityState, bool isGhost, String tabId, Color accent, MiraTheme theme) {
    if (activeUrl.isEmpty) {
      return const BrandingScreen();
    }

    if (errorMessage != null) {
      return CustomErrorScreen(
        error: errorMessage,
        url: activeUrl,
        onRetry: () {
          HapticFeedback.mediumImpact(); // --- [TACTILE] Retry bump ---
          ref.read(webErrorProvider.notifier).state = null;
          ref.read(webViewControllerProvider)?.reload();    
        },
      );
    }

    final progress = ref.watch(loadingProgressProvider);
    final bool isLoading = progress < 100;
    
    final forceDarkSetting = (theme.mode == ThemeMode.light) 
        ? ForceDark.OFF 
        : (theme.mode == ThemeMode.dark ? ForceDark.ON : ForceDark.AUTO);

    return Stack(
      children: [
        InAppWebView(
          key: ValueKey("${isGhost ? 'G' : 'N'}_$tabId"),
          initialUrlRequest: URLRequest(url: WebUri(activeUrl)),
          initialSettings: InAppWebViewSettings(
            incognito: isGhost || securityState.isIncognito, 
            clearCache: isGhost || securityState.isIncognito,
            contentBlockers: securityState.isAdBlockEnabled ? AdBlockService.adBlockRules : [],
            forceDark: forceDarkSetting,
            algorithmicDarkeningAllowed: (theme.mode == ThemeMode.dark),
            useHybridComposition: true,
            userAgent: securityState.isDesktopMode 
                ? "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" 
                : null,
            preferredContentMode: securityState.isDesktopMode 
                ? UserPreferredContentMode.DESKTOP 
                : UserPreferredContentMode.MOBILE,
          ),
          onWebViewCreated: (controller) {
            ref.read(webViewControllerProvider.notifier).state = controller;
          },
          onCreateWindow: (controller, createWindowAction) async {
            final url = createWindowAction.request.url;
            if (url == null || url.toString().isEmpty || url.toString() == 'about:blank') {
              return true; 
            }
            HapticFeedback.lightImpact(); // --- [TACTILE] New window pop ---
            final isGhost = ref.read(isGhostModeProvider);
            if (isGhost) {
              ref.read(ghostTabsProvider.notifier).add(url: url.toString());
            } else {
              ref.read(tabsProvider.notifier).add(url: url.toString());
            }
            return true;
          },
          onLoadStart: (controller, url) {
             ref.read(webErrorProvider.notifier).state = null;
             if (url != null) {
               if (isGhost) {
                 ref.read(ghostTabsProvider.notifier).updateUrl(url.toString());
               } else {
                 ref.read(tabsProvider.notifier).updateUrl(url.toString());
               }
             }
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
          onReceivedError: (controller, request, error) {
            if (error.description.contains("net::ERR_ABORTED") || 
                error.description.contains("net::ERR_NETWORK_CHANGED") ||
                error.description.contains("net::ERR_INTERNET_DISCONNECTED")) {
               return; 
            }
            if (request.isForMainFrame ?? true) {
               ref.read(webErrorProvider.notifier).state = error.description;
            }
          },
          onReceivedHttpError: (controller, request, response) {
            if (request.isForMainFrame ?? true) {
               if (response.statusCode! >= 400 && response.statusCode != 403) {
                 ref.read(webErrorProvider.notifier).state = "HTTP Error: ${response.statusCode}";
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
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            final uri = navigationAction.request.url;
            if (uri == null) return NavigationActionPolicy.ALLOW;

            if (['http', 'https', 'file', 'chrome', 'data', 'javascript', 'about'].contains(uri.scheme)) {
              return NavigationActionPolicy.ALLOW;
            }

            if (['mailto', 'tel', 'sms'].contains(uri.scheme)) {
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
                return NavigationActionPolicy.CANCEL;
              }
            }

            try {
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
                return NavigationActionPolicy.CANCEL;
              }
            } catch (e) {
              debugPrint("Deep Link failed: $e");
            }
            return NavigationActionPolicy.CANCEL; 
          },
          onDownloadStartRequest: (controller, downloadRequest) async {
              HapticFeedback.mediumImpact(); // --- [TACTILE] Download started ---
              await DownloadManager.download(
                  downloadRequest.url.toString(),
                  filename: downloadRequest.suggestedFilename
              );
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

        IgnorePointer(
          ignoring: !isLoading, 
          child: AnimatedOpacity(
            opacity: isLoading ? 1.0 : 0.0, 
            duration: const Duration(milliseconds: 500), 
            curve: Curves.easeInOut, 
            child: const WebSkeletonLoader(),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref, SecurityState securityState, bool isGhost, MiraTheme theme, Color appTextColor) {
    return Drawer(
      backgroundColor: theme.surfaceColor,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 200, 
                    width: double.infinity,
                    decoration: BoxDecoration(color: isGhost ? const Color(0xFF100000) : theme.backgroundColor),
                    child: Center(
                      child: Text(
                        'M I R A',
                        // --- [FIXED] Restored 'jetBrainsMono' ---
                        style: GoogleFonts.jetBrainsMono(
                          color: isGhost ? Colors.redAccent : theme.primaryColor, 
                          fontSize: 24, 
                          letterSpacing: 5, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                  ),
                  
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

                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 10, bottom: 5),
                    child: Text("SECURITY PROTOCOLS", style: TextStyle(color: isGhost ? Colors.redAccent : Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),

                  ListTile(
                    title: Text("New Ghost Tab", style: TextStyle(color: appTextColor)),
                    subtitle: Text("Start a private session", style: TextStyle(color: appTextColor.withAlpha(128), fontSize: 12)),
                    leading: Icon(Icons.privacy_tip_outlined, color: appTextColor.withAlpha(179)),
                    onTap: () {
                        HapticFeedback.mediumImpact(); // --- [TACTILE] Ghost Switch ---
                        ref.read(isGhostModeProvider.notifier).state = true;
                        ref.read(ghostTabsProvider.notifier).addTab();
                        Navigator.pop(context);
                    },
                  ),

                  ListTile(
                    title: const Text("Nuke Data", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                    onTap: () async {
                      HapticFeedback.selectionClick(); // Warning vibration
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: theme.surfaceColor,
                          title: Text("Nuke Everything?", style: TextStyle(color: appTextColor)), 
                          content: Text("This will wipe all history, cookies, cache, and close all tabs. This cannot be undone.", style: TextStyle(color: appTextColor.withAlpha(179))),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("Cancel", style: TextStyle(color: appTextColor.withAlpha(128)))),
                            TextButton(onPressed: () {
                                HapticFeedback.heavyImpact(); // --- [TACTILE] THE NUKE "THUD" ---
                                Navigator.pop(ctx, true);
                            }, child: const Text("NUKE IT", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      );

                      if (confirm == true) {
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

  void _updateWebViewSettings({bool forceReload = false}) async {
    final controller = ref.read(webViewControllerProvider);
    if (controller == null) return;

    final theme = ref.read(themeProvider);
    final securityState = ref.read(securityProvider);
    final isGhost = ref.read(isGhostModeProvider);
    
    final forceDarkSetting = (theme.mode == ThemeMode.light)
        ? ForceDark.OFF
        : (theme.mode == ThemeMode.dark ? ForceDark.ON : ForceDark.AUTO);

    final settings = InAppWebViewSettings(
      incognito: isGhost || securityState.isIncognito,
      clearCache: isGhost || securityState.isIncognito,
      contentBlockers: securityState.isAdBlockEnabled ? AdBlockService.adBlockRules : [],
      forceDark: forceDarkSetting,
      algorithmicDarkeningAllowed: (theme.mode == ThemeMode.dark),
      useHybridComposition: true,
      
      userAgent: securityState.isDesktopMode
          ? "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
          : null,
          
      preferredContentMode: securityState.isDesktopMode
          ? UserPreferredContentMode.DESKTOP
          : UserPreferredContentMode.MOBILE,
    );

    try {
      await controller.setSettings(settings: settings);
      if (forceReload) {
        controller.reload();
      }
    } catch (e) {
      debugPrint("WebView settings update safe fail: $e");
    }
  }
}