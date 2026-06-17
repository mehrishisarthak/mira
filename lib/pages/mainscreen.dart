import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mira/shell/desktop/desktop_windowing.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:mira/core/notifiers/bookmarks_notifier.dart';
import 'package:mira/core/notifiers/theme_notifier.dart';
import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/search_notifier.dart';
import 'package:mira/core/notifiers/security_notifier.dart';
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/core/entities/tab_entity.dart';
import 'package:mira/core/entities/theme_entity.dart';
import 'package:mira/core/providers/adblock_provider.dart';
import 'package:mira/core/services/browser_engine_blueprints.dart';
import 'package:mira/core/services/database_providers.dart';
import 'package:mira/pages/browser_chrome_providers.dart';
import 'package:mira/pages/browser/browser_view.dart';
import 'package:mira/pages/main_screen/desktop_browser_chrome.dart';
import 'package:mira/pages/main_screen/desktop_platform_menus.dart';
import 'package:mira/pages/main_screen/desktop_sidebar.dart';
import 'package:mira/pages/main_screen/main_screen_haptics.dart';
import 'package:mira/pages/main_screen/main_screen_security.dart';
import 'package:mira/pages/main_screen/mobile_main_app_bar.dart' show buildMobileBottomBar;
import 'package:mira/shell/desktop/desktop_browser_hotkeys.dart';
import 'package:mira/shell/desktop/desktop_find_bar.dart';

class Mainscreen extends ConsumerStatefulWidget {
  const Mainscreen({super.key});

  @override
  ConsumerState<Mainscreen> createState() => _MainscreenState();
}

class _MainscreenState extends ConsumerState<Mainscreen> with WidgetsBindingObserver {
  DateTime? _lastExitTime;
  DateTime? _lastAutoHealAt;
  Timer? _titleSyncDebounce;

  late final TextEditingController _urlController;
  late final FocusNode _urlFocusNode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final initialUrl = ref.read(currentActiveTabProvider).url;
    _urlController = TextEditingController(text: initialUrl);
    _urlFocusNode = FocusNode();
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      HardwareKeyboard.instance.addHandler(_handleDesktopHotkey);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncDesktopWindowTitle(ref.read(currentActiveTabProvider));
      });
    }
  }

  void _syncDesktopWindowTitle(BrowserTab tab) {
    if (kIsWeb ||
        !(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      return;
    }
    _titleSyncDebounce?.cancel();
    _titleSyncDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      final raw = tab.title.trim();
      final label = raw.isEmpty ? 'Mira' : raw;
      final isGhost = ref.read(isGhostModeProvider);
      if (isGhost) {
        await desktopSetWindowTitle(
          raw.isEmpty ? 'MIRA Private' : '$label — MIRA Private',
        );
      } else {
        await desktopSetWindowTitle('$label — Mira');
      }
    });
  }

  @override
  void dispose() {
    _titleSyncDebounce?.cancel();
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      HardwareKeyboard.instance.removeHandler(_handleDesktopHotkey);
    }
    WidgetsBinding.instance.removeObserver(this);
    _urlController.dispose();
    _urlFocusNode.dispose();
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
    final engine = ref.read(browserChromeProvider).engine;
    if (engine == null) {
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
        final engine = ref.read(browserChromeProvider).engine;
        engine?.reload();
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
    if (value.trim().isEmpty) return;
    
    _triggerHaptic(MainScreenHapticKind.light);
    ref.read(browserChromeProvider.notifier).clearWebError();

    String finalUrl;
    String trimmedValue = value.trim();
    
    if (_isValidUrl(trimmedValue)) {
      finalUrl = trimmedValue.startsWith("http") ? trimmedValue : "https://$trimmedValue";
    } else {
      finalUrl = ref.read(formattedSearchUrlProvider(trimmedValue));
    }
    
    final isGhost = ref.read(isGhostModeProvider);
    if (isGhost) {
      ref.read(ghostTabsProvider.notifier).updateUrl(finalUrl);
    } else {
      ref.read(tabsProvider.notifier).updateUrl(finalUrl);
    }

    final engine = ref.read(activeBrowserEngineProvider);
    engine?.loadUrl(finalUrl);

    if (mounted) {
      _urlFocusNode.unfocus();
      _urlController.text = finalUrl;
      _urlController.selection =
          TextSelection.collapsed(offset: finalUrl.length);
    }
  }

  void _handlePop() async {
    final chrome = ref.read(browserChromeProvider);
    final engine = chrome.engine;
    final errorMessage = chrome.webError;
    final activeUrl = ref.read(currentActiveTabProvider).url;
    final isGhost = ref.read(isGhostModeProvider);
    final appTheme = ref.read(themeProvider);

    if (engine != null && await engine.canGoBack()) {
      if (errorMessage != null) {
        ref.read(browserChromeProvider.notifier).clearWebError();
      }
      engine.goBack();
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

  void _handleBrowserBack() async {
    final engine = ref.read(browserChromeProvider).engine;
    if (engine != null && await engine.canGoBack()) {
      if (ref.read(browserChromeProvider).webError != null) {
        ref.read(browserChromeProvider.notifier).clearWebError();
      }
      engine.goBack();
      _triggerHaptic(MainScreenHapticKind.selection);
      return;
    }
    final activeUrl = ref.read(currentActiveTabProvider).url;
    if (activeUrl.isNotEmpty) {
      _triggerHaptic(MainScreenHapticKind.light);
      if (ref.read(isGhostModeProvider)) {
        ref.read(ghostTabsProvider.notifier).updateUrl('');
      } else {
        ref.read(tabsProvider.notifier).updateUrl('');
      }
      ref.read(browserChromeProvider.notifier).clearWebError();
    }
  }

  Future<void> _applyAdBlockToAllTabs(bool enabled) async {
    final List<AdBlockRule> adBlockRules = enabled
        ? await ref.read(adBlockRulesProvider.future)
        : const <AdBlockRule>[];

    if (!mounted) return;

    final theme = ref.read(themeProvider);
    final security = ref.read(securityProvider);

    final config = BrowserEngineConfig(
      isDesktopMode: security.isDesktopMode,
      isDarkMode: theme.mode == ThemeMode.dark,
      isCameraBlocked: security.isCameraBlocked,
      isLocationBlocked: security.isLocationBlocked,
      adBlockRules: adBlockRules,
    );

    final allTabs = [
      ...ref.read(tabsProvider).tabs,
      ...ref.read(ghostTabsProvider).tabs,
    ];

    for (final tab in allTabs) {
      if (!mounted) return;
      try {
        final engine = ref.read(browserEngineProvider(tab.id));
        await engine.updateSettings(config);
        await engine.reload();
      } catch (e) {
        debugPrint('MIRA: AdBlock update failed for tab ${tab.id}: $e');
      }
    }
  }

  void _toggleGhostMode() {
    final isGhost = ref.read(isGhostModeProvider);
    if (isGhost) {
      ref.read(isGhostModeProvider.notifier).state = false;
    } else {
      if (ref.read(ghostTabsProvider).tabs.isEmpty) {
        ref.read(ghostTabsProvider.notifier).addTab();
      }
      ref.read(isGhostModeProvider.notifier).state = true;
    }
    _triggerHaptic(MainScreenHapticKind.medium);
  }

  @override
  Widget build(BuildContext context) {
    final isGhost = ref.watch(isGhostModeProvider);
    final activeTab = ref.watch(currentActiveTabProvider);

    final activeUrl = activeTab.url;
    final normalTabsList = ref.watch(tabsProvider).tabs;
    final ghostTabsList = ref.watch(ghostTabsProvider).tabs;
    final tabCount = isGhost ? ghostTabsList.length : normalTabsList.length;
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
    final contentColor = (isLightMode && !isGhost) ? kMiraInkPrimary : Colors.white;
    final hintColor = (isLightMode && !isGhost) ? kMiraInkMuted : Colors.white30;

    final engine = ref.watch(browserChromeProvider).engine;
    final hasWebView = engine != null;

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

    // Single source of truth for security-driven engine sync.
    // Theme changes are handled by browser_side_effects.dart's themeProvider listener.
    ref.listen(securityProvider, (prev, next) {
      if (prev?.isDesktopMode != next.isDesktopMode) {
        unawaited(applyMainScreenWebViewSettings(ref, forceReload: true));
      }
      if (prev?.isCameraBlocked != next.isCameraBlocked ||
          prev?.isLocationBlocked != next.isLocationBlocked) {
        unawaited(applyMainScreenWebViewSettings(ref));
      }
      if (prev?.isAdBlockEnabled != next.isAdBlockEnabled) {
        unawaited(_applyAdBlockToAllTabs(next.isAdBlockEnabled));
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
        appBar: null,
        bottomNavigationBar: null,
        body: isDesktop
            ? Row(
                children: [
                  const DesktopSidebar(),
                  Expanded(
                    child: Column(
                      children: [
                        buildDesktopToolbar(
                          context: context,
                          ref: ref,
                          bgColor: isGhost ? const Color(0xFF1A1A1A) : appBarColor,
                          contentColor: contentColor,
                          accentColor: primaryAccent,
                          hintColor: hintColor,
                          activeTab: activeTab,
                          isGhost: isGhost,
                          securityIcon: securityIcon,
                          securityColor: securityColor,
                          isBookmarked: isBookmarked,
                          progress: progress,
                          hasWebView: hasWebView,
                          urlController: _urlController,
                          urlFocusNode: _urlFocusNode,
                          onUrlSubmitted: _performSearch,
                          onFindPressed: _openDesktopFindBar,
                        ),
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              const BrowserView(),
                              const _GhostModeFlash(),
                              if (ref.watch(desktopFindBarVisibleProvider))
                                const Positioned(
                                  top: 8,
                                  right: 12,
                                  child: SizedBox(
                                    width: 340,
                                    child: DesktopFindBar(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : SafeArea(
                top: true,
                bottom: false,
                child: Column(
                  children: [
                    const Expanded(child: BrowserView()),
                    buildMobileBottomBar(
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
                      onBackPressed: () => _handleBrowserBack(),
                      onGhostToggle: _toggleGhostMode,
                    ),
                  ],
                ),
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
        ),
        child: shell,
      );
    }

    return shell;
  }
}

// ── Ghost mode context-switch flash overlay ────────────────────────────────────

class _GhostModeFlash extends ConsumerStatefulWidget {
  const _GhostModeFlash();

  @override
  ConsumerState<_GhostModeFlash> createState() => _GhostModeFlashState();
}

class _GhostModeFlashState extends ConsumerState<_GhostModeFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  Color _color = Colors.redAccent;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 550),
      vsync: this,
    );
    // Fade in quickly, hold briefly, fade out slowly.
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.20), weight: 25),
      TweenSequenceItem(tween: ConstantTween(0.20), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.20, end: 0.0), weight: 60),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(isGhostModeProvider, (prev, next) {
      if (prev == next) return;
      _color = next ? Colors.redAccent : Colors.black87;
      _controller.forward(from: 0);
    });

    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, __) => IgnorePointer(
        child: Opacity(
          opacity: _opacity.value,
          child: ColoredBox(color: _color, child: const SizedBox.expand()),
        ),
      ),
    );
  }
}
