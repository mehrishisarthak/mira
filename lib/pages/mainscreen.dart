import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';

import 'package:mira/shell/ad_block/ad_block_service_webview.dart';
import 'package:mira/core/entities/bookmark_entity.dart';
import 'package:mira/core/notifiers/bookmarks_notifier.dart';
import 'package:mira/core/entities/theme_entity.dart';
import 'package:mira/core/notifiers/theme_notifier.dart';
import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/search_notifier.dart';
import 'package:mira/core/notifiers/history_notifier.dart';
import 'package:mira/core/entities/security_entity.dart';
import 'package:mira/core/notifiers/security_notifier.dart'; 
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/core/entities/tab_entity.dart';
import 'package:mira/core/notifiers/proxy_notifier.dart';
import 'package:mira/shell/proxy/proxy_provider.dart'; 
import 'package:mira/pages/browser_view.dart'; 
import 'package:mira/pages/mira_drawer.dart';
import 'package:mira/pages/tab_screen.dart'; 

// --- LOCAL PROVIDERS ---
final loadingProgressProvider = StateProvider<int>((ref) => 0);
final webViewControllerProvider = StateProvider<InAppWebViewController?>((ref) => null);
final webErrorProvider = StateProvider<String?>((ref) => null); 

class Mainscreen extends ConsumerStatefulWidget {
  const Mainscreen({super.key});

  @override
  ConsumerState<Mainscreen> createState() => _MainscreenState();
}

class _MainscreenState extends ConsumerState<Mainscreen> with WidgetsBindingObserver {
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
    String trimmed = value.trim();
    if (trimmed.contains(' ')) return false;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return true;
    
    final domainRegExp = RegExp(
      r'^(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}|' 
      r'^localhost|' 
      r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$'
    );
    return domainRegExp.hasMatch(trimmed);
  }

  void _triggerHaptic(HapticFeedbackType type) {
    if (kIsWeb) return;
    if (Platform.isAndroid || Platform.isIOS) {
      switch (type) {
        case HapticFeedbackType.light:
          HapticFeedback.lightImpact();
          break;
        case HapticFeedbackType.medium:
          HapticFeedback.mediumImpact();
          break;
        case HapticFeedbackType.selection:
          HapticFeedback.selectionClick();
          break;
      }
    }
  }

  void _performSearch(String value) {
    if (value.isEmpty) return;
    
    _triggerHaptic(HapticFeedbackType.light);
    ref.read(webErrorProvider.notifier).state = null;

    String finalUrl;
    String trimmedValue = value.trim();
    
    if (_isValidUrl(trimmedValue)) {
      finalUrl = trimmedValue.startsWith("http") ? trimmedValue : "https://$trimmedValue";
    } else {
      finalUrl = ref.read(formattedSearchUrlProvider(trimmedValue));
    }
    
    final gateway = ref.read(proxyServiceProvider);
    final isGatewayRunning = ref.read(proxyGatewayStatusProvider);
    final security = ref.read(securityProvider);
    if (!kIsWeb && Platform.isIOS && security.isProxyEnabled && isGatewayRunning) {
        finalUrl = gateway.getProxiedUrl(finalUrl);
    }
    
    final isGhost = ref.read(isGhostModeProvider);
    if (isGhost) {
      ref.read(ghostTabsProvider.notifier).updateUrl(finalUrl);
    } else {
      ref.read(historyProvider.notifier).addToHistory(trimmedValue);
      ref.read(tabsProvider.notifier).updateUrl(finalUrl);
    }

    final controller = ref.read(webViewControllerProvider);
    if (controller != null) {
      controller.loadUrl(
        urlRequest: URLRequest(url: WebUri(finalUrl))
      );
    }
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
      _triggerHaptic(HapticFeedbackType.light);
      if (isGhost) {
        ref.read(ghostTabsProvider.notifier).updateUrl('');
      } else {
        ref.read(tabsProvider.notifier).updateUrl('');
      }
      ref.read(webErrorProvider.notifier).state = null;
      return;
    }

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final now = DateTime.now();
      if (_lastExitTime == null ||
          now.difference(_lastExitTime!) > const Duration(seconds: 2)) {
        _lastExitTime = now;
        if (mounted) {
          _triggerHaptic(HapticFeedbackType.selection);
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
    } else {
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGhost = ref.watch(isGhostModeProvider);
    final activeTab = ref.watch(currentActiveTabProvider);
    ref.watch(proxyGatewayStatusProvider);

    final activeUrl = activeTab.url;
    final currentTabsList = ref.watch(currentTabListProvider);
    final tabCount = currentTabsList.length;
    final double progress = ref.watch(loadingProgressProvider) / 100;
    
    final bookmarks = ref.watch(bookmarksProvider);
    final isBookmarked = bookmarks.any((b) => b.url == activeUrl);
    final appTheme = ref.watch(themeProvider);
    
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

    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    ref.listen(currentActiveTabProvider, (previous, next) {
      if (previous?.id != next.id) {
        ref.read(loadingProgressProvider.notifier).state = 0;
        ref.read(webViewControllerProvider.notifier).state = null; 
      }
    });

    ref.listen(themeProvider, (_, __) => _updateWebViewSettings(forceReload: false));
    ref.listen(securityProvider, (prev, next) {
      if (prev?.isDesktopMode != next.isDesktopMode || 
          prev?.isAdBlockEnabled != next.isAdBlockEnabled) {
        _updateWebViewSettings(forceReload: true);
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handlePop();
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: isDesktop ? null : _buildMobileAppBar(appBarColor, securityIcon, securityColor, activeUrl, textController, contentColor, primaryAccent, isGhost, hintColor, isBookmarked, activeTab, tabCount, progress),
        body: Column(
          children: [
            if (isDesktop) _buildDesktopTopBar(appBarColor, contentColor, primaryAccent, currentTabsList, activeTab, isGhost, securityIcon, securityColor, textController, hintColor, isBookmarked, progress),
            const Expanded(child: BrowserView()),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar(Color appBarColor, IconData securityIcon, Color securityColor, String activeUrl, TextEditingController textController, Color contentColor, Color primaryAccent, bool isGhost, Color hintColor, bool isBookmarked, dynamic activeTab, int tabCount, double progress) {
    return AppBar(
      backgroundColor: appBarColor,
      titleSpacing: 0,
      leading: IconButton(
        icon: Icon(securityIcon, color: securityColor),
        onPressed: () => _showSecurityDialog(activeUrl, securityColor, contentColor),
      ),
      title: TextField(
        controller: textController,
        style: GoogleFonts.jetBrainsMono(color: contentColor, fontWeight: FontWeight.w500, fontSize: 14),
        cursorColor: primaryAccent,
        decoration: InputDecoration(
          hintText: isGhost ? 'Ghost Mode Active' : 'Search or enter address',
          border: InputBorder.none,
          hintStyle: GoogleFonts.jetBrainsMono(color: hintColor),
          suffixIcon: activeUrl.isNotEmpty && !isGhost
              ? IconButton(
                  icon: Icon(isBookmarked ? Icons.star : Icons.star_border, color: isBookmarked ? Colors.yellowAccent : hintColor, size: 20),
                  onPressed: () {
                    _triggerHaptic(HapticFeedbackType.selection);
                    ref.read(bookmarksProvider.notifier).toggleBookmark(activeUrl, activeTab.title);
                  },
                )
              : null,
        ),
        textInputAction: TextInputAction.go,
        onTap: () => textController.selection = TextSelection(baseOffset: 0, extentOffset: textController.text.length),
        onSubmitted: _performSearch,
      ),
      actions: [
        InkWell(
          onTap: () {
            _triggerHaptic(HapticFeedbackType.selection);
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
            decoration: BoxDecoration(color: primaryAccent, borderRadius: BorderRadius.circular(8)),
            child: Text("$tabCount", style: GoogleFonts.jetBrainsMono(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        IconButton(
          icon: Icon(Icons.more_vert, color: contentColor),
          onPressed: () {
            _triggerHaptic(HapticFeedbackType.selection);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MiraMenuPage()),
            );
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: progress < 1.0 
          ? LinearProgressIndicator(value: progress, backgroundColor: Colors.transparent, color: primaryAccent)
          : Container(height: 2, color: Colors.transparent),
      ),
    );
  }

  Widget _buildDesktopTopBar(Color bgColor, Color contentColor, Color accentColor, List<BrowserTab> tabs, BrowserTab activeTab, bool isGhost, IconData securityIcon, Color securityColor, TextEditingController textController, Color hintColor, bool isBookmarked, double progress) {
    return Container(
      color: bgColor,
      child: Column(
        children: [
          // Tab Strip
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: tabs.length,
                    itemBuilder: (context, index) {
                      final tab = tabs[index];
                      final isActive = tab.id == activeTab.id;
                      return GestureDetector(
                        onTap: () {
                          if (isGhost) {
                            ref.read(ghostTabsProvider.notifier).switchTab(index);
                          } else {
                            ref.read(tabsProvider.notifier).switchTab(index);
                          }
                        },
                        child: Container(
                          width: 180,
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isActive ? accentColor.withValues(alpha: 0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: isActive ? Border.all(color: accentColor.withValues(alpha: 0.5)) : null,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tab.title.isEmpty ? "New Tab" : tab.title,
                                  style: GoogleFonts.jetBrainsMono(color: contentColor, fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.normal),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (tabs.length > 1)
                                GestureDetector(
                                  onTap: () {
                                    if (isGhost) {
                                      ref.read(ghostTabsProvider.notifier).closeTab(tab.id);
                                    } else {
                                      ref.read(tabsProvider.notifier).closeTab(tab.id);
                                    }
                                  },
                                  child: Icon(Icons.close, size: 14, color: contentColor.withValues(alpha: 0.5)),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add, color: contentColor, size: 20),
                  onPressed: () {
                    if (isGhost) {
                      ref.read(ghostTabsProvider.notifier).addTab();
                    } else {
                      ref.read(tabsProvider.notifier).addTab();
                    }
                  },
                ),
              ],
            ),
          ),
          // Toolbar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: contentColor, size: 20),
                  onPressed: () => ref.read(webViewControllerProvider)?.goBack(),
                ),
                IconButton(
                  icon: Icon(Icons.arrow_forward, color: contentColor, size: 20),
                  onPressed: () => ref.read(webViewControllerProvider)?.goForward(),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: contentColor, size: 20),
                  onPressed: () => ref.read(webViewControllerProvider)?.reload(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: contentColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Icon(securityIcon, color: securityColor, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: textController,
                            style: GoogleFonts.jetBrainsMono(color: contentColor, fontSize: 13),
                            cursorColor: accentColor,
                            decoration: InputDecoration(
                              hintText: isGhost ? 'Ghost Mode Active' : 'Search or enter address',
                              border: InputBorder.none,
                              isDense: true,
                              hintStyle: GoogleFonts.jetBrainsMono(color: hintColor, fontSize: 13),
                            ),
                            onSubmitted: _performSearch,
                          ),
                        ),
                        if (textController.text.isNotEmpty && !isGhost)
                          IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(isBookmarked ? Icons.star : Icons.star_border, color: isBookmarked ? Colors.yellowAccent : hintColor, size: 18),
                            onPressed: () => ref.read(bookmarksProvider.notifier).toggleBookmark(textController.text, activeTab.title),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.more_vert, color: contentColor, size: 20),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MiraMenuPage()),
                  ),
                ),
              ],
            ),
          ),
          if (progress < 1.0)
            LinearProgressIndicator(value: progress, backgroundColor: Colors.transparent, color: accentColor, minHeight: 2),
        ],
      ),
    );
  }

  void _showSecurityDialog(String activeUrl, Color securityColor, Color contentColor) {
    if (activeUrl.isEmpty) return;
    final appTheme = ref.read(themeProvider);
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
      contentBlockers: securityState.isAdBlockEnabled ? AdBlockServiceWebview.contentBlockers : [],
      forceDark: forceDarkSetting,
      algorithmicDarkeningAllowed: (theme.mode == ThemeMode.dark),
      useHybridComposition: !kIsWeb && Platform.isAndroid,
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

enum HapticFeedbackType {
  light,
  medium,
  selection
}




