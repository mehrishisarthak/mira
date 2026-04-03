import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';

import 'package:mira/shell/ad_block/ad_block_service_webview.dart';
import 'package:mira/core/notifiers/bookmarks_notifier.dart';
import 'package:mira/core/notifiers/theme_notifier.dart';
import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/search_notifier.dart';
import 'package:mira/core/notifiers/history_notifier.dart';
import 'package:mira/core/notifiers/security_notifier.dart'; 
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/core/entities/tab_entity.dart';
import 'package:mira/core/notifiers/proxy_notifier.dart';
import 'package:mira/core/services/proxy_service.dart';
import 'package:mira/shell/proxy/proxy_provider.dart'; 
import 'package:mira/core/entities/theme_entity.dart';
import 'package:mira/pages/browser_chrome_providers.dart';
import 'package:mira/pages/browser_view.dart';
import 'package:mira/pages/mira_drawer.dart';
import 'package:mira/pages/tab_screen.dart';
import 'package:mira/shell/desktop/desktop_browser_hotkeys.dart';
import 'package:mira/shell/desktop/desktop_find_bar.dart';

class Mainscreen extends ConsumerStatefulWidget {
  const Mainscreen({super.key});

  @override
  ConsumerState<Mainscreen> createState() => _MainscreenState();
}

class _MainscreenState extends ConsumerState<Mainscreen> with WidgetsBindingObserver {
  DateTime? _lastExitTime;

  late final TextEditingController _urlController;
  late final FocusNode _urlFocusNode;
  ScrollController? _desktopTabScrollController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final initialUrl = ref.read(currentActiveTabProvider).url;
    _urlController = TextEditingController(text: initialUrl);
    _urlFocusNode = FocusNode();
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      _desktopTabScrollController = ScrollController();
      HardwareKeyboard.instance.addHandler(_handleDesktopHotkey);
    }
  }

  @override
  void dispose() {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      HardwareKeyboard.instance.removeHandler(_handleDesktopHotkey);
    }
    WidgetsBinding.instance.removeObserver(this);
    _urlController.dispose();
    _urlFocusNode.dispose();
    _desktopTabScrollController?.dispose();
    super.dispose();
  }

  bool _handleDesktopHotkey(KeyEvent event) {
    return handleDesktopBrowserHotkey(
      event: event,
      mounted: mounted,
      ref: ref,
      urlFocusNode: _urlFocusNode,
      urlController: _urlController,
      openFindDialog: _openDesktopFindBar,
    );
  }

  void _openDesktopFindBar() {
    if (!mounted) return;
    final find = ref.read(activeFindInteractionProvider);
    final web = ref.read(browserChromeProvider).controller;
    if (find == null && web == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Open a web page tab to use find in page.'),
        ),
      );
      return;
    }
    ref.read(desktopFindBarVisibleProvider.notifier).state = true;
  }

  List<PlatformMenu> _desktopPlatformMenus() {
    return [
      PlatformMenu(
        label: 'File',
        menus: [
          PlatformMenuItem(
            label: 'New Tab',
            onSelected: () {
              ref.read(tabsProvider.notifier).addTab();
              ref.read(isGhostModeProvider.notifier).state = false;
            },
          ),
          PlatformMenuItem(
            label: 'Close Tab',
            onSelected: () {
              final ghost = ref.read(isGhostModeProvider);
              final active = ref.read(currentActiveTabProvider);
              if (ghost) {
                ref.read(ghostTabsProvider.notifier).closeTab(active.id);
              } else {
                ref.read(tabsProvider.notifier).closeTab(active.id);
              }
            },
          ),
          PlatformMenuItem(
            label: 'Exit',
            onSelected: () => SystemNavigator.pop(),
          ),
        ],
      ),
      PlatformMenu(
        label: 'Edit',
        menus: [
          PlatformMenuItem(
            label: 'Find in Page…',
            onSelected: _openDesktopFindBar,
          ),
          PlatformMenuItem(
            label: 'Focus Address Bar',
            onSelected: () {
              _urlFocusNode.requestFocus();
              _urlController.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _urlController.text.length,
              );
            },
          ),
        ],
      ),
      PlatformMenu(
        label: 'View',
        menus: [
          PlatformMenuItem(
            label: 'Reload',
            onSelected: () =>
                ref.read(browserChromeProvider).controller?.reload(),
          ),
        ],
      ),
    ];
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (ref.read(browserChromeProvider).webError != null) {
         debugPrint("System: App Resumed. Healing broken connection...");
         ref.read(browserChromeProvider.notifier).clearWebError();
         final controller = ref.read(browserChromeProvider).controller;
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
    ref.read(browserChromeProvider.notifier).clearWebError();

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
    if (!kIsWeb &&
        gateway.runtimeBackend == ProxyRuntimeBackend.iosLocalGateway &&
        security.isProxyEnabled &&
        isGatewayRunning) {
      finalUrl = gateway.getProxiedUrl(finalUrl);
    }
    
    final isGhost = ref.read(isGhostModeProvider);
    if (isGhost) {
      ref.read(ghostTabsProvider.notifier).updateUrl(finalUrl);
    } else {
      ref.read(historyProvider.notifier).addToHistory(trimmedValue);
      ref.read(tabsProvider.notifier).updateUrl(finalUrl);
    }

    final controller = ref.read(browserChromeProvider).controller;
    if (controller != null) {
      controller.loadUrl(
        urlRequest: URLRequest(url: WebUri(finalUrl))
      );
    }

    if (mounted) {
      _urlController.text = finalUrl;
      _urlController.selection =
          TextSelection.collapsed(offset: finalUrl.length);
    }
  }

  void _handlePop() async {
    final chrome = ref.read(browserChromeProvider);
    final controller = chrome.controller;
    final errorMessage = chrome.webError;
    final activeUrl = ref.read(currentActiveTabProvider).url;
    final isGhost = ref.read(isGhostModeProvider);
    final appTheme = ref.read(themeProvider);

    if (errorMessage != null) {
      if (await controller?.canGoBack() ?? false) {
        ref.read(browserChromeProvider.notifier).clearWebError();
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
      ref.read(browserChromeProvider.notifier).clearWebError();
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
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGhost = ref.watch(isGhostModeProvider);
    final activeTab = ref.watch(currentActiveTabProvider);
    ref.watch(proxyGatewayStatusProvider);

    final activeUrl = activeTab.url;
    final normalTabsList = ref.watch(tabsProvider).tabs;
    final ghostTabsList = ref.watch(ghostTabsProvider).tabs;
    final tabCount = normalTabsList.length + ghostTabsList.length;
    final double progress = ref.watch(browserChromeProvider).loadingProgress / 100;
    
    final bookmarks = ref.watch(bookmarksProvider);
    final isBookmarked = bookmarks.any((b) => b.url == activeUrl);
    final appTheme = ref.watch(themeProvider);
    
    final backgroundColor = appTheme.backgroundColor;
    final appBarColor = appTheme.surfaceColor;
    final primaryAccent = isGhost ? Colors.redAccent : appTheme.primaryColor;
    final isLightMode = appTheme.mode == ThemeMode.light;
    final contentColor = isLightMode ? kMiraInkPrimary : Colors.white;
    final hintColor = isLightMode ? kMiraInkMuted : Colors.white30;

    final webController = ref.watch(browserChromeProvider).controller;
    final hasWebView = webController != null;

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
        _urlController.text = next.url;
        _urlController.selection =
            TextSelection.collapsed(offset: next.url.length);
      } else if (previous?.url != next.url && !_urlFocusNode.hasFocus) {
        _urlController.text = next.url;
        _urlController.selection =
            TextSelection.collapsed(offset: next.url.length);
      }
    });

    // Theme → WebView settings sync is handled by BrowserView._applyThemeToAllControllers.
    // Only listen to security for desktop-mode / ad-block toggles that need a page reload.
    ref.listen(securityProvider, (prev, next) {
      if (prev?.isDesktopMode != next.isDesktopMode ||
          prev?.isAdBlockEnabled != next.isAdBlockEnabled) {
        _updateWebViewSettings(forceReload: true);
      }
    });

    Widget shell = PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handlePop();
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: isDesktop
            ? null
            : _buildMobileAppBar(
                appBarColor,
                securityIcon,
                securityColor,
                activeUrl,
                contentColor,
                primaryAccent,
                isGhost,
                hintColor,
                isBookmarked,
                activeTab,
                tabCount,
                progress,
              ),
        body: Column(
          children: [
            if (isDesktop)
              _buildDesktopTopBar(
                appBarColor,
                contentColor,
                primaryAccent,
                normalTabsList,
                ghostTabsList,
                activeTab,
                isGhost,
                appTheme.primaryColor,
                securityIcon,
                securityColor,
                hintColor,
                isBookmarked,
                progress,
                hasWebView,
              ),
            Expanded(
              child: isDesktop
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        const BrowserView(),
                        if (ref.watch(desktopFindBarVisibleProvider))
                          const Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: DesktopFindBar(),
                          ),
                      ],
                    )
                  : const BrowserView(),
            ),
          ],
        ),
      ),
    );

    if (isDesktop) {
      shell = PlatformMenuBar(
        menus: _desktopPlatformMenus(),
        child: shell,
      );
    }

    return shell;
  }

  PreferredSizeWidget _buildMobileAppBar(
    Color appBarColor,
    IconData securityIcon,
    Color securityColor,
    String activeUrl,
    Color contentColor,
    Color primaryAccent,
    bool isGhost,
    Color hintColor,
    bool isBookmarked,
    BrowserTab activeTab,
    int tabCount,
    double progress,
  ) {
    return AppBar(
      backgroundColor: appBarColor,
      titleSpacing: 0,
      leading: IconButton(
        icon: Icon(securityIcon, color: securityColor),
        onPressed: () => _showSecurityDialog(activeUrl, securityColor, contentColor),
      ),
      title: TextField(
        controller: _urlController,
        focusNode: _urlFocusNode,
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
        onTap: () => _urlController.selection = TextSelection(baseOffset: 0, extentOffset: _urlController.text.length),
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
        child: progress < 1.0 && activeUrl.isNotEmpty
          ? LinearProgressIndicator(value: progress, backgroundColor: Colors.transparent, color: primaryAccent)
          : Container(height: 2, color: Colors.transparent),
      ),
    );
  }

  Widget _buildDesktopTabChip({
    required BrowserTab tab,
    required int stackIndex,
    required bool tabIsGhost,
    required Color tabAccent,
    required bool showClose,
    required BrowserTab activeTab,
    required bool sessionIsGhost,
    required Color contentColor,
  }) {
    final isActive =
        tab.id == activeTab.id && tabIsGhost == sessionIsGhost;
    final idleBorder = tabIsGhost
        ? Border.all(color: Colors.redAccent.withValues(alpha: 0.35))
        : null;

    return GestureDetector(
      onTap: () {
        ref.read(isGhostModeProvider.notifier).state = tabIsGhost;
        if (tabIsGhost) {
          ref.read(ghostTabsProvider.notifier).switchTab(stackIndex);
        } else {
          ref.read(tabsProvider.notifier).switchTab(stackIndex);
        }
      },
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? tabAccent.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isActive
              ? Border.all(color: tabAccent.withValues(alpha: 0.65), width: 1.5)
              : idleBorder,
        ),
        child: Row(
          children: [
            if (tabIsGhost)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.privacy_tip_outlined,
                  size: 14,
                  color: Colors.redAccent.withValues(alpha: isActive ? 1 : 0.65),
                ),
              ),
            Expanded(
              child: Text(
                tab.title.isEmpty
                    ? (tabIsGhost ? "Ghost Tab" : "New Tab")
                    : tab.title,
                style: GoogleFonts.jetBrainsMono(
                  color: contentColor,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showClose)
              GestureDetector(
                onTap: () {
                  if (tabIsGhost) {
                    ref.read(ghostTabsProvider.notifier).closeTab(tab.id);
                  } else {
                    ref.read(tabsProvider.notifier).closeTab(tab.id);
                  }
                },
                child: Icon(Icons.close,
                    size: 14, color: contentColor.withValues(alpha: 0.5)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTopBar(
    Color bgColor,
    Color contentColor,
    Color accentColor,
    List<BrowserTab> normalTabs,
    List<BrowserTab> ghostTabs,
    BrowserTab activeTab,
    bool isGhost,
    Color themePrimary,
    IconData securityIcon,
    Color securityColor,
    Color hintColor,
    bool isBookmarked,
    double progress,
    bool hasWebView,
  ) {
    final stripChildren = <Widget>[];
    for (var i = 0; i < normalTabs.length; i++) {
      stripChildren.add(
        _buildDesktopTabChip(
          tab: normalTabs[i],
          stackIndex: i,
          tabIsGhost: false,
          tabAccent: themePrimary,
          showClose: normalTabs.length > 1,
          activeTab: activeTab,
          sessionIsGhost: isGhost,
          contentColor: contentColor,
        ),
      );
    }
    if (normalTabs.isNotEmpty && ghostTabs.isNotEmpty) {
      stripChildren.add(
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 1,
          height: 22,
          color: contentColor.withValues(alpha: 0.2),
        ),
      );
    }
    for (var i = 0; i < ghostTabs.length; i++) {
      stripChildren.add(
        _buildDesktopTabChip(
          tab: ghostTabs[i],
          stackIndex: i,
          tabIsGhost: true,
          tabAccent: Colors.redAccent,
          showClose: ghostTabs.length > 1,
          activeTab: activeTab,
          sessionIsGhost: isGhost,
          contentColor: contentColor,
        ),
      );
    }

    return Container(
      color: bgColor,
      child: Column(
        children: [
          // Tab Strip — normal tabs first, then ghost (red accent)
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Listener(
                    onPointerSignal: (signal) {
                      if (signal is PointerScrollEvent) {
                        final c = _desktopTabScrollController;
                        if (c != null && c.hasClients) {
                          final next = (c.offset + signal.scrollDelta.dy)
                              .clamp(0.0, c.position.maxScrollExtent);
                          c.jumpTo(next);
                        }
                      }
                    },
                    child: ListView(
                      controller: _desktopTabScrollController,
                      scrollDirection: Axis.horizontal,
                      children: stripChildren,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'New tab',
                  icon: Icon(Icons.add, color: contentColor, size: 20),
                  onPressed: () {
                    ref.read(tabsProvider.notifier).addTab();
                    ref.read(isGhostModeProvider.notifier).state = false;
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
                  tooltip: 'Back',
                  onPressed: hasWebView
                      ? () => ref.read(browserChromeProvider).controller?.goBack()
                      : null,
                ),
                IconButton(
                  icon: Icon(Icons.arrow_forward, color: contentColor, size: 20),
                  tooltip: 'Forward',
                  onPressed: hasWebView
                      ? () =>
                          ref.read(browserChromeProvider).controller?.goForward()
                      : null,
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: contentColor, size: 20),
                  tooltip: 'Reload',
                  onPressed: hasWebView
                      ? () => ref.read(browserChromeProvider).controller?.reload()
                      : null,
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
                        Tooltip(
                          message: activeTab.url.isEmpty
                              ? 'Site info'
                              : 'Connection & site info',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: activeTab.url.isEmpty
                                ? null
                                : () => _showSecurityDialog(
                                    activeTab.url, securityColor, contentColor),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(securityIcon,
                                  color: securityColor, size: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _urlController,
                            focusNode: _urlFocusNode,
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
                        if (activeTab.url.isNotEmpty && !isGhost)
                          IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(isBookmarked ? Icons.star : Icons.star_border, color: isBookmarked ? Colors.yellowAccent : hintColor, size: 18),
                            onPressed: () => ref.read(bookmarksProvider.notifier).toggleBookmark(activeTab.url, activeTab.title),
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
          if (progress < 1.0 && activeTab.url.isNotEmpty)
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
    final controller = ref.read(browserChromeProvider).controller;
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




