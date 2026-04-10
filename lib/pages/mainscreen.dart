import 'package:flutter/material.dart';
import 'package:mira/shell/desktop/desktop_windowing.dart';
import 'package:flutter/services.dart'; 
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:io';
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
import 'package:mira/pages/browser/browser_view.dart';
import 'package:mira/pages/main_screen/desktop_browser_chrome.dart';
import 'package:mira/pages/main_screen/desktop_platform_menus.dart';
import 'package:mira/pages/main_screen/main_screen_haptics.dart';
import 'package:mira/pages/main_screen/main_screen_security.dart';
import 'package:mira/pages/main_screen/mobile_main_app_bar.dart';
import 'package:mira/shell/desktop/desktop_browser_hotkeys.dart';
import 'package:mira/shell/desktop/desktop_find_bar.dart';

class Mainscreen extends ConsumerStatefulWidget {
  /// Desktop-only: separate OS window created by [desktop_multi_window].
  final bool isPrivateBrowserWindow;

  const Mainscreen({
    super.key,
    this.isPrivateBrowserWindow = false,
  });

  @override
  ConsumerState<Mainscreen> createState() => _MainscreenState();
}

class _MainscreenState extends ConsumerState<Mainscreen> with WidgetsBindingObserver {
  DateTime? _lastExitTime;
  DateTime? _lastAutoHealAt;

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncDesktopWindowTitle(ref.read(currentActiveTabProvider));
      });
    }
    if (widget.isPrivateBrowserWindow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(isGhostModeProvider.notifier).state = true;
        if (ref.read(ghostTabsProvider).tabs.isEmpty) {
          ref.read(ghostTabsProvider.notifier).addTab();
        }
      });
    }
  }

  Future<void> _syncDesktopWindowTitle(BrowserTab tab) async {
    if (kIsWeb ||
        !(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      return;
    }
    final raw = tab.title.trim();
    final label = raw.isEmpty ? 'Mira' : raw;
    if (widget.isPrivateBrowserWindow) {
      await desktopSetWindowTitle(
        raw.isEmpty ? 'MIRA Private' : '$label — MIRA Private',
      );
    } else {
      await desktopSetWindowTitle('$label — Mira');
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
      standalonePrivateWindow: widget.isPrivateBrowserWindow,
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (ref.read(browserChromeProvider).webError != null) {
        // On desktop, "resumed" fires on every window-focus gain. Debounce
        // so a persistent error doesn't trigger an infinite reload loop.
        final now = DateTime.now();
        if (_lastAutoHealAt != null &&
            now.difference(_lastAutoHealAt!) < const Duration(seconds: 30)) {
          return;
        }
        _lastAutoHealAt = now;
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

  void _triggerHaptic(MainScreenHapticKind type) {
    if (kIsWeb) return;
    if (Platform.isAndroid || Platform.isIOS) {
      switch (type) {
        case MainScreenHapticKind.light:
          HapticFeedback.lightImpact();
          break;
        case MainScreenHapticKind.medium:
          HapticFeedback.mediumImpact();
          break;
        case MainScreenHapticKind.selection:
          HapticFeedback.selectionClick();
          break;
      }
    }
  }

  void _performSearch(String value) {
    if (value.isEmpty) return;
    
    _triggerHaptic(MainScreenHapticKind.light);
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
      _triggerHaptic(MainScreenHapticKind.light);
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
          _triggerHaptic(MainScreenHapticKind.selection);
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

    if (!kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      ref.listen<BrowserTab>(currentActiveTabProvider, (prev, next) {
        _syncDesktopWindowTitle(next);
      });
    }
    
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

    final isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final desktopTabStripLayout = !isDesktop
        ? DesktopTabStripLayout.mainBrowser
        : (widget.isPrivateBrowserWindow
            ? DesktopTabStripLayout.privateWindow
            : DesktopTabStripLayout.mainBrowser);

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
        applyMainScreenWebViewSettings(ref, forceReload: true);
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
            : buildMobileMainAppBar(
                context: context,
                ref: ref,
                urlController: _urlController,
                urlFocusNode: _urlFocusNode,
                appBarColor: appBarColor,
                securityIcon: securityIcon,
                securityColor: securityColor,
                activeUrl: activeUrl,
                contentColor: contentColor,
                primaryAccent: primaryAccent,
                isGhost: isGhost,
                hintColor: hintColor,
                isBookmarked: isBookmarked,
                activeTab: activeTab,
                tabCount: tabCount,
                progress: progress,
                triggerHaptic: _triggerHaptic,
                onUrlSubmitted: _performSearch,
              ),
        body: Column(
          children: [
            if (isDesktop)
              buildDesktopMainChrome(
                context: context,
                ref: ref,
                bgColor: appBarColor,
                contentColor: contentColor,
                accentColor: primaryAccent,
                normalTabs: normalTabsList,
                ghostTabs: ghostTabsList,
                activeTab: activeTab,
                isGhost: isGhost,
                tabStripLayout: desktopTabStripLayout,
                themePrimary: appTheme.primaryColor,
                securityIcon: securityIcon,
                securityColor: securityColor,
                hintColor: hintColor,
                isBookmarked: isBookmarked,
                progress: progress,
                hasWebView: hasWebView,
                tabScrollController: _desktopTabScrollController,
                urlController: _urlController,
                urlFocusNode: _urlFocusNode,
                onUrlSubmitted: _performSearch,
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
        menus: buildDesktopMainPlatformMenus(
          ref: ref,
          openDesktopFindBar: _openDesktopFindBar,
          urlFocusNode: _urlFocusNode,
          urlController: _urlController,
          standalonePrivateWindow: widget.isPrivateBrowserWindow,
        ),
        child: shell,
      );
    }

    return shell;
  }
}




