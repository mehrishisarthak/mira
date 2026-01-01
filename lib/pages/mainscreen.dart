import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mira/model/ad_block_model.dart';
import 'package:mira/model/book_mark_model.dart';
import 'package:mira/model/theme_model.dart';
import 'package:mira/model/ghost_model.dart';
import 'package:mira/model/search_engine.dart';
import 'package:mira/model/security_model.dart'; 
import 'package:mira/model/tab_model.dart';
import 'package:mira/pages/browser_view.dart'; 
import 'package:mira/pages/mira_drawer.dart';
import 'package:mira/pages/tab_screen.dart'; // [NEW] Import View

// --- LOCAL PROVIDERS (Keep these here or move to a general_providers.dart) ---
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

    if (errorMessage != null) {
      if (await controller?.canGoBack() ?? false) {
        ref.read(webErrorProvider.notifier).state = null;
        controller?.goBack();
        return;
      }
    }

    if (controller != null && await controller.canGoBack()) {
      controller.goBack();
      return;
    }

    if (activeUrl.isNotEmpty) {
      HapticFeedback.lightImpact(); 
      if (isGhost) {
        ref.read(ghostTabsProvider.notifier).updateUrl('');
      } else {
        ref.read(tabsProvider.notifier).updateUrl('');
      }
      ref.read(webErrorProvider.notifier).state = null;
      return;
    }

    final now = DateTime.now();
    if (_lastExitTime == null ||
        now.difference(_lastExitTime!) > const Duration(seconds: 2)) {
      _lastExitTime = now;
      if (mounted) {
        HapticFeedback.selectionClick(); 
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
    final double progress = ref.watch(loadingProgressProvider) / 100;
    
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

    // --- LISTENERS (Logic Layer) ---

    // 1. Tab Switch -> Reset Progress & Controller
    ref.listen(currentActiveTabProvider, (previous, next) {
      if (previous?.id != next.id) {
        ref.read(loadingProgressProvider.notifier).state = 0;
        ref.read(webViewControllerProvider.notifier).state = null; 
      }
    });

    // 2. Smart Settings Updates (The Controller Logic)
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
        // --- [NEW] Use the extracted Drawer Widget ---
        endDrawer: const MiraDrawer(),
        
        appBar: AppBar(
          backgroundColor: appBarColor,
          titleSpacing: 0,
          leading: IconButton(
            icon: Icon(securityIcon, color: securityColor),
            onPressed: () {
              if (activeUrl.isNotEmpty) {
                HapticFeedback.selectionClick(); 
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
            style: GoogleFonts.jetBrainsMono(
              color: contentColor,
              fontWeight: FontWeight.w500,
              fontSize: 14, 
            ), 
            cursorColor: primaryAccent,
            decoration: InputDecoration(
              hintText: isGhost ? 'Ghost Mode Active' : 'Search or enter address',
              border: InputBorder.none,
              hintStyle: GoogleFonts.jetBrainsMono(color: hintColor), 
              suffixIcon: activeUrl.isNotEmpty && !isGhost
                  ? IconButton(
                      icon: Icon(
                        isBookmarked ? Icons.star : Icons.star_border,
                        color: isBookmarked ? Colors.yellowAccent : hintColor,
                        size: 20,
                      ),
                      onPressed: () {
                          HapticFeedback.selectionClick(); 
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
                 HapticFeedback.lightImpact(); 
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
                HapticFeedback.selectionClick(); 
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
                HapticFeedback.selectionClick(); 
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
        
        // --- [NEW] Use the extracted Browser View Widget ---
        body: const BrowserView(),
      ),
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