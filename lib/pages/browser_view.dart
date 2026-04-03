import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'dart:io';

import 'package:mira/shell/ad_block/ad_block_service_webview.dart';
import 'package:mira/shell/browser/browser_provider.dart';
import 'package:mira/core/notifiers/hibernation_notifier.dart';
import 'package:mira/core/services/download_provider.dart';
import 'package:mira/core/entities/theme_entity.dart';
import 'package:mira/core/notifiers/theme_notifier.dart';
import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/entities/security_entity.dart';
import 'package:mira/core/notifiers/security_notifier.dart'; 
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/core/entities/tab_entity.dart';
import 'package:mira/core/notifiers/proxy_notifier.dart';
import 'package:mira/core/services/proxy_service.dart';
import 'package:mira/shell/proxy/proxy_provider.dart'; 

import 'package:mira/pages/branding_screen.dart';
import 'package:mira/pages/custom_error_screen.dart'; 
import 'package:mira/pages/skelleton_loader.dart';
import 'package:mira/pages/browser_chrome_providers.dart';

class BrowserView extends ConsumerStatefulWidget {
  const BrowserView({super.key});

  @override
  ConsumerState<BrowserView> createState() => _BrowserViewState();
}

class _BrowserViewState extends ConsumerState<BrowserView> with WidgetsBindingObserver {
  final Map<String, InAppWebViewController> _controllers = {};
  final Map<String, FindInteractionController> _findControllers = {};
  final Map<String, int> _lastProgressByTabId = {};
  Timer? _skeletonDismissTimer;
  /// Set in [onWebViewCreated] for the active tab so we do not mark load 100% for a new mount.
  String? _webviewJustCreatedForTabId;

  static const _skeletonAutoDismiss = Duration(seconds: 14);

  bool get _supportsNativeFindInteraction {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  // ── LIFECYCLE ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Register once for the widget lifetime — not in build() where new closures
    // would be created every frame and the listener cascade causes redraws.
    _registerBrowserSideEffectListeners();

    // Initial wake for active tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isGhost = ref.read(isGhostModeProvider);
      final initialState = isGhost ? ref.read(ghostTabsProvider) : ref.read(tabsProvider);
      if (initialState.tabs.isNotEmpty) {
        final activeId = initialState.tabs[initialState.activeIndex].id;
        ref.read(hibernationProvider.notifier).wakeTab(activeId);
      }

      // Initial proxy application
      final security = ref.read(securityProvider);
      ref.read(browserServiceProvider).applyProxy(security);
    });
  }

  @override
  void dispose() {
    _skeletonDismissTimer?.cancel();
    for (final c in _findControllers.values) {
      try {
        c.dispose();
      } catch (_) {}
    }
    _findControllers.clear();
    WidgetsBinding.instance.removeObserver(this);
    _controllers.clear();
    super.dispose();
  }

  void _cancelSkeletonDismissTimer() {
    _skeletonDismissTimer?.cancel();
    _skeletonDismissTimer = null;
  }

  /// SPAs sometimes never report progress 100; still clear after [onLoadStop],
  /// but this guarantees the overlay cannot stick forever.
  void _armSkeletonDismissTimer(String tabIdWhenArmed) {
    _cancelSkeletonDismissTimer();
    _skeletonDismissTimer = Timer(_skeletonAutoDismiss, () {
      if (!mounted) return;
      final ghost = ref.read(isGhostModeProvider);
      final state = ghost ? ref.read(ghostTabsProvider) : ref.read(tabsProvider);
      if (state.tabs.isEmpty) return;
      final activeId = state.tabs[state.activeIndex].id;
      if (activeId != tabIdWhenArmed) return;
      ref.read(browserChromeProvider.notifier).setLoadingProgress(100);
    });
  }

  bool _isLinkHitType(InAppWebViewHitTestResultType? type) {
    return type == InAppWebViewHitTestResultType.SRC_ANCHOR_TYPE ||
        type == InAppWebViewHitTestResultType.SRC_IMAGE_ANCHOR_TYPE;
  }

  /// Desktop / WebView2: right-click raises [ContextMenu.onCreateContextMenu].
  ContextMenu? _desktopLinkContextMenu() {
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) return null;
    return ContextMenu(
      settings: ContextMenuSettings(
        hideDefaultSystemContextMenuItems: false,
      ),
      onCreateContextMenu: (hitTestResult) {
        final url = hitTestResult.extra;
        if (url != null &&
            url.isNotEmpty &&
            _isLinkHitType(hitTestResult.type)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showLinkContextMenu(url);
          });
        }
      },
    );
  }

  String? _activeTabIdFromState(TabsState? state) {
    if (state == null || state.tabs.isEmpty) return null;
    final idx = state.activeIndex;
    if (idx < 0 || idx >= state.tabs.length) return null;
    return state.tabs[idx].id;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      for (var controller in _controllers.values) {
        try {
          controller.pause();
        } catch (e) {
          debugPrint("Safe Pause Fail: $e");
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      final isGhost = ref.read(isGhostModeProvider);
      final tabsState = isGhost ? ref.read(ghostTabsProvider) : ref.read(tabsProvider);
      if (tabsState.tabs.isNotEmpty) {
        final activeTabId = tabsState.tabs[tabsState.activeIndex].id;
        try {
          _controllers[activeTabId]?.resume();
        } catch (e) {
          debugPrint("Safe Resume Fail: $e");
        }
      }
    }
  }

  void _updateControllersPauseState(String activeTabId) {
    _controllers.forEach((id, controller) {
      try {
        if (id == activeTabId) {
          controller.resume();
        } else {
          controller.pause();
        }
      } catch (e) {
        debugPrint("Safe Pause/Resume Fail for $id: $e");
      }
    });
  }

  void _cleanUpClosedTabs(List<dynamic> currentTabs) {
    final currentTabIds = currentTabs.map((tab) => tab.id as String).toSet();
    final removedIds =
        _controllers.keys.where((id) => !currentTabIds.contains(id)).toList();
    for (final id in removedIds) {
      _lastProgressByTabId.remove(id);
      try {
        _findControllers[id]?.dispose();
      } catch (_) {}
      _findControllers.remove(id);
    }
    _controllers.removeWhere((id, _) => !currentTabIds.contains(id));
    ref.read(hibernationProvider.notifier).onTabsClosed(currentTabIds);
  }

  /// Pushes updated theme/dark-mode settings to every live WebView controller.
  Future<void> _applyThemeToAllControllers(MiraTheme theme) async {
    if (_controllers.isEmpty) return;
    final securityState = ref.read(securityProvider);
    final isGhost = ref.read(isGhostModeProvider);

    final forceDarkSetting = (theme.mode == ThemeMode.light)
        ? ForceDark.OFF
        : (theme.mode == ThemeMode.dark ? ForceDark.ON : ForceDark.AUTO);

    final settings = InAppWebViewSettings(
      incognito: isGhost || securityState.isIncognito,
      clearCache: isGhost || securityState.isIncognito,
      contentBlockers:
          securityState.isAdBlockEnabled ? AdBlockServiceWebview.contentBlockers : [],
      forceDark: forceDarkSetting,
      algorithmicDarkeningAllowed: (theme.mode == ThemeMode.dark),
      useHybridComposition: !kIsWeb && Platform.isAndroid,
      transparentBackground: false,
      userAgent: securityState.isDesktopMode
          ? "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
          : null,
      preferredContentMode: securityState.isDesktopMode
          ? UserPreferredContentMode.DESKTOP
          : UserPreferredContentMode.MOBILE,
    );

    for (final controller in _controllers.values) {
      try {
        await controller.setSettings(settings: settings);
      } catch (e) {
        debugPrint("Theme sync safe fail: $e");
      }
    }
  }

  /// Binds [browserChromeProvider] to the active tab's live WebView.
  ///
  /// [updateProgress] is false on a post-frame pass so a newly created WebView after
  /// hibernation is not marked complete until [onLoadStart]/[onProgressChanged] run.
  void _syncChromeToActiveWebView(BrowserTab active, {bool updateProgress = true}) {
    final awake = ref.read(hibernationProvider);
    final hasLiveWebView = active.url.isNotEmpty && awake.contains(active.id);
    final ctrl = hasLiveWebView ? _controllers[active.id] : null;
    final chrome = ref.read(browserChromeProvider.notifier);
    chrome.setController(ctrl);
    if (!updateProgress) return;
    if (hasLiveWebView && ctrl != null) {
      if (_webviewJustCreatedForTabId == active.id) {
        return;
      }
      final stored = _lastProgressByTabId[active.id];
      chrome.setLoadingProgress(stored ?? 100);
    } else if (active.url.isEmpty) {
      chrome.setLoadingProgress(100);
    } else {
      chrome.setLoadingProgress(0);
    }
  }

  Widget _buildHibernatedPlaceholder(BrowserTab tab) {
    final bg = ref.read(themeProvider).backgroundColor;
    return Container(
      color: bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.refresh_rounded, size: 40, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              tab.title.isEmpty ? 'New Tab' : tab.title,
              style: const TextStyle(color: Colors.white30, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Tracks the last pointer-down position for desktop context-menu placement.
  Offset? _lastPointerPosition;

  void _showLinkContextMenu(String linkUrl) {
    if (!mounted) return;
    final theme = ref.read(themeProvider);
    final isGhost = ref.read(isGhostModeProvider);
    final isLight = theme.mode == ThemeMode.light;
    final textColor = isLight ? kMiraInkPrimary : Colors.white;
    final isDesktop = !kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    if (isDesktop) {
      _showDesktopLinkPopup(linkUrl, theme, isGhost, textColor);
    } else {
      _showMobileLinkSheet(linkUrl, theme, isGhost, textColor);
    }
  }

  void _showDesktopLinkPopup(
      String linkUrl, dynamic theme, bool isGhost, Color textColor) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = _lastPointerPosition ?? overlay.localToGlobal(Offset.zero);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      color: theme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          height: 32,
          child: Text(
            linkUrl.length > 60 ? '${linkUrl.substring(0, 60)}…' : linkUrl,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.5),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 'copy',
          child: Row(children: [
            Icon(Icons.copy, color: textColor, size: 18),
            const SizedBox(width: 10),
            Text('Copy Link', style: TextStyle(color: textColor, fontSize: 13)),
          ]),
        ),
        PopupMenuItem(
          value: 'newtab',
          child: Row(children: [
            Icon(Icons.tab_outlined, color: textColor, size: 18),
            const SizedBox(width: 10),
            Text('Open in New Tab',
                style: TextStyle(color: textColor, fontSize: 13)),
          ]),
        ),
        PopupMenuItem(
          value: 'external',
          child: Row(children: [
            Icon(Icons.open_in_browser, color: textColor, size: 18),
            const SizedBox(width: 10),
            Text('Open in External Browser',
                style: TextStyle(color: textColor, fontSize: 13)),
          ]),
        ),
        PopupMenuItem(
          value: 'download',
          child: Row(children: [
            Icon(Icons.download_outlined, color: textColor, size: 18),
            const SizedBox(width: 10),
            Text('Download Link',
                style: TextStyle(color: textColor, fontSize: 13)),
          ]),
        ),
      ],
    ).then((action) {
      if (action == null || !mounted) return;
      switch (action) {
        case 'copy':
          Clipboard.setData(ClipboardData(text: linkUrl));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Link copied')),
          );
          break;
        case 'newtab':
          if (isGhost) {
            ref.read(ghostTabsProvider.notifier).addTab(url: linkUrl);
          } else {
            ref.read(tabsProvider.notifier).addTab(url: linkUrl);
          }
          break;
        case 'external':
          final uri = Uri.tryParse(linkUrl);
          if (uri != null) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
          }
          break;
        case 'download':
          ref.read(downloadsProvider.notifier).startDownload(linkUrl);
          break;
      }
    });
  }

  void _showMobileLinkSheet(
      String linkUrl, dynamic theme, bool isGhost, Color textColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  linkUrl,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.copy, color: textColor),
              title: Text('Copy Link', style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: linkUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.tab_outlined, color: textColor),
              title:
                  Text('Open in New Tab', style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(ctx);
                HapticFeedback.lightImpact();
                if (isGhost) {
                  ref.read(ghostTabsProvider.notifier).addTab(url: linkUrl);
                } else {
                  ref.read(tabsProvider.notifier).addTab(url: linkUrl);
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.open_in_browser, color: textColor),
              title: Text('Open in External Browser',
                  style: TextStyle(color: textColor)),
              onTap: () async {
                Navigator.pop(ctx);
                final uri = Uri.tryParse(linkUrl);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.download_outlined, color: textColor),
              title:
                  Text('Download Link', style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(ctx);
                HapticFeedback.mediumImpact();
                ref.read(downloadsProvider.notifier).startDownload(linkUrl);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _getEffectiveUrl(String originalUrl, SecurityState security) {
    if (originalUrl.isEmpty) return originalUrl;
    
    final gateway = ref.read(proxyServiceProvider);
    final isGatewayRunning = ref.read(proxyGatewayStatusProvider);
    if (!kIsWeb &&
        gateway.runtimeBackend == ProxyRuntimeBackend.iosLocalGateway &&
        security.isProxyEnabled &&
        isGatewayRunning) {
      if (originalUrl.startsWith('http://localhost')) return originalUrl;
      return gateway.getProxiedUrl(originalUrl);
    }
    return originalUrl;
  }

  /// Side effects only — must run from [build] every frame (Riverpod [ref.listen]).
  ///
  /// Order matters:
  /// 1. Tab lists (wake LRU target, pause/resume WebViews, clear errors on id change)
  /// 2. Ghost session switch
  /// 3. Security / proxy wiring, theme push to engines
  /// 4. Hibernation eviction (drop controller maps **before** rebinding chrome)
  /// 5. Active tab → [browserChromeProvider] + find controller
  void _registerBrowserSideEffectListeners() {
    ref.listen(tabsProvider, (previous, next) {
      if (!ref.read(isGhostModeProvider)) {
        final prevId = _activeTabIdFromState(previous);
        final nextId = _activeTabIdFromState(next);
        if (prevId != nextId) {
          ref.read(browserChromeProvider.notifier).clearWebError();
          _cancelSkeletonDismissTimer();
        }
        _cleanUpClosedTabs(next.tabs);
        if (previous?.activeIndex != next.activeIndex && next.tabs.isNotEmpty) {
          final newActiveId = next.tabs[next.activeIndex].id;
          ref.read(hibernationProvider.notifier).wakeTab(newActiveId);
          _updateControllersPauseState(newActiveId);
        }
      }
    });

    ref.listen(ghostTabsProvider, (previous, next) {
      if (ref.read(isGhostModeProvider)) {
        final prevId = _activeTabIdFromState(previous);
        final nextId = _activeTabIdFromState(next);
        if (prevId != nextId) {
          ref.read(browserChromeProvider.notifier).clearWebError();
          _cancelSkeletonDismissTimer();
        }
        _cleanUpClosedTabs(next.tabs);
        if (previous?.activeIndex != next.activeIndex && next.tabs.isNotEmpty) {
          final newActiveId = next.tabs[next.activeIndex].id;
          ref.read(hibernationProvider.notifier).wakeTab(newActiveId);
          _updateControllersPauseState(newActiveId);
        }
      }
    });

    ref.listen(isGhostModeProvider, (_, isGhostNow) {
      ref.read(browserChromeProvider.notifier).clearWebError();
      _cancelSkeletonDismissTimer();
      final switchedState = isGhostNow
          ? ref.read(ghostTabsProvider)
          : ref.read(tabsProvider);
      if (switchedState.tabs.isNotEmpty) {
        final activeId = switchedState.tabs[switchedState.activeIndex].id;
        ref.read(hibernationProvider.notifier).wakeTab(activeId);
      }
    });

    ref.listen(securityProvider, (previous, next) {
      if (previous?.isProxyEnabled != next.isProxyEnabled ||
          previous?.proxyUrl != next.proxyUrl) {
        ref.read(browserServiceProvider).applyProxy(next);
      }
    });

    ref.listen(themeProvider, (_, next) => _applyThemeToAllControllers(next));

    ref.listen(hibernationProvider, (previous, next) {
      final prev = previous ?? <String>{};
      for (final id in prev.difference(next)) {
        _controllers.remove(id);
        _lastProgressByTabId.remove(id);
        try {
          _findControllers[id]?.dispose();
        } catch (_) {}
        _findControllers.remove(id);
      }
    });

    ref.listen(currentActiveTabProvider, (previous, next) {
      ref.read(activeFindInteractionProvider.notifier).state =
          _supportsNativeFindInteraction ? _findControllers[next.id] : null;
      if (previous?.id != next.id) {
        _syncChromeToActiveWebView(next);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _webviewJustCreatedForTabId = null;
          final now = ref.read(currentActiveTabProvider);
          if (now.id != next.id) return;
          _syncChromeToActiveWebView(now, updateProgress: false);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isGhost = ref.watch(isGhostModeProvider);

    // Structural watch: rebuilds only when tab count / ordering / active index /
    // url-presence changes — NOT on every URL or title mutation that WebView
    // callbacks fire during page load. This breaks the main rebuild cascade.
    ref.watch(
      (isGhost ? ghostTabsProvider : tabsProvider).select((s) =>
          '${s.activeIndex}|${s.tabs.map((t) => '${t.id}:${t.url.isEmpty ? 0 : 1}').join(',')}'),
    );
    // Read (not watch) the full state: consistent with the structural key above
    // and avoids a second subscription to the same provider.
    final tabsState = ref.read(isGhost ? ghostTabsProvider : tabsProvider);
    final tabs = tabsState.tabs;
    final activeIndex = tabsState.activeIndex;
    final activeTabId = tabs.isNotEmpty ? tabs[activeIndex].id : '';

    final awakeTabIds = ref.watch(hibernationProvider);

    // Security & theme are read, not watched.  `initialSettings` are consumed
    // once at WebView mount; live updates to already-mounted WebViews are pushed
    // by `ref.listen` handlers registered in initState
    // (_applyThemeToAllControllers, applyProxy, _updateWebViewSettings).
    final securityState = ref.read(securityProvider);
    final theme = ref.read(themeProvider);

    // Only watch webError (rare change). Loading progress is isolated inside
    // _WebViewSkeletonOverlay so onProgressChanged never rebuilds the WebView stack.
    final errorMessage = ref.watch(browserChromeProvider.select((s) => s.webError));

    if (errorMessage != null && tabs.isNotEmpty) {
      return CustomErrorScreen(
        error: errorMessage,
        url: tabs[activeIndex].url,
        onRetry: () {
          HapticFeedback.mediumImpact();
          ref.read(browserChromeProvider.notifier).clearWebError();
          final retryController = ref.read(browserChromeProvider).controller;
          if (retryController != null) {
            retryController.reload();
          } else {
            debugPrint('[MIRA] C01: onRetry called with null controller, clearing error only');
          }
        },
      );
    }
    
    final forceDarkSetting = (theme.mode == ThemeMode.light) 
        ? ForceDark.OFF 
        : (theme.mode == ThemeMode.dark ? ForceDark.ON : ForceDark.AUTO);

    return Listener(
      onPointerDown: (e) => _lastPointerPosition = e.position,
      child: Stack(
      children: [
        // Keep desktop WebView surfaces laid out even when hidden; offstage-style
        // hiding can make WebView2 lose paint/input until the next resize.
        ...tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isShowing = index == activeIndex;

          Widget content;
          if (tab.url.isEmpty) {
            content = const BrandingScreen();
          } else if (!awakeTabIds.contains(tab.id)) {
            content = _buildHibernatedPlaceholder(tab);
          } else {
            final findCtrl = _supportsNativeFindInteraction
                ? _findControllers.putIfAbsent(
                    tab.id,
                    () => FindInteractionController(),
                  )
                : null;

            content = InAppWebView(
              key: ObjectKey(tab.id),
              initialUrlRequest: URLRequest(url: WebUri(_getEffectiveUrl(tab.url, securityState))),
              contextMenu: _desktopLinkContextMenu(),
              findInteractionController: findCtrl,
              initialUserScripts: securityState.isAdBlockEnabled
                  ? UnmodifiableListView<UserScript>(AdBlockServiceWebview.initialUserScripts)
                  : null,
                  
              initialSettings: InAppWebViewSettings(
                incognito: isGhost || securityState.isIncognito, 
                clearCache: isGhost || securityState.isIncognito,
                cacheMode: CacheMode.LOAD_DEFAULT, 
                
                contentBlockers: securityState.isAdBlockEnabled ? AdBlockServiceWebview.contentBlockers : [],
                forceDark: forceDarkSetting,
                algorithmicDarkeningAllowed: (theme.mode == ThemeMode.dark),
                useHybridComposition: !kIsWeb && Platform.isAndroid,
                hardwareAcceleration: true,
                transparentBackground: false,
                userAgent: securityState.isDesktopMode 
                    ? "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" 
                    : null,
                preferredContentMode: securityState.isDesktopMode 
                    ? UserPreferredContentMode.DESKTOP 
                    : UserPreferredContentMode.MOBILE,
              ),
              shouldInterceptRequest: (controller, request) async {
                // Read at request time so the callback always reflects the
                // current toggle state, even though build() no longer re-runs
                // on every securityProvider change.
                if (!ref.read(securityProvider).isAdBlockEnabled) return null;
                final host = request.url.host;
                if (AdBlockServiceWebview.blockedDomains.any((domain) => host.contains(domain))) {
                  return WebResourceResponse(
                    contentType: 'text/plain',
                    data: Uint8List(0),
                  );
                }
                return null;
              },
              onWebViewCreated: (controller) {
                _controllers[tab.id] = controller;
                final isGhostNow = ref.read(isGhostModeProvider);
                final currentState = isGhostNow ? ref.read(ghostTabsProvider) : ref.read(tabsProvider);
                final currentActiveId = currentState.tabs.isNotEmpty 
                    ? currentState.tabs[currentState.activeIndex].id 
                    : '';
                if (tab.id == currentActiveId) {
                  _webviewJustCreatedForTabId = tab.id;
                  final n = ref.read(browserChromeProvider.notifier);
                  n.setLoadingProgress(0);
                  n.setController(controller);
                  ref.read(activeFindInteractionProvider.notifier).state =
                      _supportsNativeFindInteraction ? _findControllers[tab.id] : null;
                }
              },
              onCreateWindow: (controller, createWindowAction) async {
                final url = createWindowAction.request.url;
                if (url == null || url.toString().isEmpty || url.toString() == 'about:blank') return true;
                if (isGhost) {
                  ref.read(ghostTabsProvider.notifier).addTab(url: url.toString());
                } else {
                  ref.read(tabsProvider.notifier).addTab(url: url.toString());
                }
                return true;
              },
              onLoadStart: (controller, url) {
                 _lastProgressByTabId[tab.id] = 0;
                 if (tab.id == activeTabId) {
                   ref.read(browserChromeProvider.notifier).clearWebError();
                   _armSkeletonDismissTimer(tab.id);
                 }
                 if (url != null) {
                   final urlString = url.toString();
                   final displayUrl = urlString.contains('localhost') && urlString.contains('/http') 
                       ? urlString.split('/http').last.replaceFirst('s:', 'https:').replaceFirst(':', 'http:')
                       : urlString;
                    if (isGhost) {
                      ref.read(ghostTabsProvider.notifier).updateUrlForTab(
                        tab.id,
                        displayUrl,
                      );
                    } else {
                      ref.read(tabsProvider.notifier).updateUrlForTab(
                        tab.id,
                        displayUrl,
                      );
                    }
                  }
               },
              onProgressChanged: (controller, p) {
                _lastProgressByTabId[tab.id] = p;
                if (tab.id == activeTabId) {
                  ref.read(browserChromeProvider.notifier).setLoadingProgress(p);
                }
              },
              onLoadStop: (controller, url) {
                  _lastProgressByTabId[tab.id] = 100;
                  if (tab.id == activeTabId) {
                    _cancelSkeletonDismissTimer();
                    ref.read(browserChromeProvider.notifier).setLoadingProgress(100);
                  }
                   if (url != null) {
                     if (isGhost) {
                      ref.read(ghostTabsProvider.notifier).updateUrlForTab(
                        tab.id,
                        url.toString(),
                      );
                     } else {
                      ref.read(tabsProvider.notifier).updateUrlForTab(
                        tab.id,
                        url.toString(),
                      );
                     }
                   }
               },
              onReceivedError: (controller, request, error) {
                if (request.isForMainFrame ?? true) {
                   if (tab.id == activeTabId) {
                     ref.read(browserChromeProvider.notifier).setWebError(error.description);
                   }
                }
              },
              onTitleChanged: (controller, title) {
                if (title != null) {
                    if (isGhost) {
                      ref.read(ghostTabsProvider.notifier).updateTitleForTab(
                        tab.id,
                        title,
                      );
                    } else {
                      ref.read(tabsProvider.notifier).updateTitleForTab(
                        tab.id,
                        title,
                      );
                    }
                  }
              },
            );
          }

          return Positioned.fill(
            key: ValueKey('vis_${tab.id}'),
            child: IgnorePointer(
              ignoring: !isShowing,
              child: Opacity(
                opacity: isShowing ? 1.0 : 0.0,
                child: content,
              ),
            ),
          );
        }),

        // Skeleton overlay lives in its own ConsumerWidget so that
        // onProgressChanged callbacks only rebuild it, not the WebView stack.
        const _WebViewSkeletonOverlay(),
      ],
    ));
  }
}

/// Isolated skeleton overlay — watches [browserChromeProvider] loading progress
/// independently so that the ~100 [onProgressChanged] callbacks per navigation
/// rebuild only this tiny widget, never the WebView stack above.
class _WebViewSkeletonOverlay extends ConsumerWidget {
  const _WebViewSkeletonOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress =
        ref.watch(browserChromeProvider.select((s) => s.loadingProgress));
    final activeTabUrl =
        ref.watch(currentActiveTabProvider.select((t) => t.url));
    // Desktop platform views handle their own loading chrome and the opaque
    // skeleton blocks mouse interaction (scroll, click) until progress == 100.
    final isDesktop = !kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final isLoading = !isDesktop && progress < 100 && activeTabUrl.isNotEmpty;
    return IgnorePointer(
      ignoring: !isLoading,
      child: AnimatedOpacity(
        opacity: isLoading ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        child: const WebSkeletonLoader(),
      ),
    );
  }
}
