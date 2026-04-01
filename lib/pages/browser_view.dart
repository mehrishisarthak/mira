import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'dart:io';

import 'package:mira/model/ad_block_model.dart';
import 'package:mira/core/services/download_provider.dart';
import 'package:mira/model/theme_model.dart';
import 'package:mira/model/ghost_model.dart';
import 'package:mira/model/security_model.dart'; 
import 'package:mira/model/tab_model.dart';
import 'package:mira/model/proxy_gateway.dart'; 

import 'package:mira/pages/branding_screen.dart';
import 'package:mira/pages/custom_error_screen.dart'; 
import 'package:mira/pages/skelleton_loader.dart';
import 'package:mira/pages/mainscreen.dart'; 

class BrowserView extends ConsumerStatefulWidget {
  const BrowserView({super.key});

  @override
  ConsumerState<BrowserView> createState() => _BrowserViewState();
}

class _BrowserViewState extends ConsumerState<BrowserView> with WidgetsBindingObserver {
  final Map<String, InAppWebViewController> _controllers = {};

  // ── TAB HIBERNATION ────────────────────────────────────────────────────────
  // Only _maxAliveTabs WebView instances are kept live at once.
  // All other tabs render as a lightweight placeholder and are reloaded on demand.
  static const int _maxAliveTabs = 3;

  // LinkedHashSet preserves insertion order (oldest first), making LRU eviction
  // trivial: remove the first element.
  final LinkedHashSet<String> _awakeTabIds = LinkedHashSet<String>();

  /// Marks [tabId] as the most-recently-used tab. If the awake set exceeds
  /// [_maxAliveTabs], the least-recently-used tab is evicted (hibernated).
  /// Its controller reference is released so Flutter disposes the WebView.
  void _wakeTab(String tabId) {
    _awakeTabIds.remove(tabId); // re-insert to move it to the end (most recent)
    _awakeTabIds.add(tabId);

    while (_awakeTabIds.length > _maxAliveTabs) {
      final lruId = _awakeTabIds.first;
      _awakeTabIds.remove(lruId);
      _controllers.remove(lruId);
      debugPrint('MIRA_HIBERNATE: Tab $lruId hibernated (LRU eviction, limit=$_maxAliveTabs)');
    }

    if (mounted) setState(() {});
  }

  // ── LIFECYCLE ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Seed the awake set with the initial active tab so the first build
    // renders a live WebView instead of a placeholder.
    final isGhost = ref.read(isGhostModeProvider);
    final initialState = isGhost ? ref.read(ghostTabsProvider) : ref.read(tabsProvider);
    if (initialState.tabs.isNotEmpty) {
      _awakeTabIds.add(initialState.tabs[initialState.activeIndex].id);
    }

    // Apply proxy config after the first frame (platform channels are ready).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialSecurityState = ref.read(securityProvider);
      _applyProxy(initialSecurityState);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controllers.clear();
    _awakeTabIds.clear();
    super.dispose();
  }

  // Helper method to apply proxy settings globally (Android Only)
  Future<void> _applyProxy(securityState) async {
    if (!kIsWeb && Platform.isAndroid) {
      final proxyController = ProxyController.instance();
      final isSupported = await WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE);
      
      if (isSupported) {
        if (securityState.isProxyEnabled && securityState.proxyUrl.isNotEmpty) {
          await proxyController.setProxyOverride(
            settings: ProxySettings(
              proxyRules: [
                ProxyRule(url: securityState.proxyUrl)
              ],
              bypassRules: ["*.local"],
            ),
          );
        } else {
          await proxyController.clearProxyOverride();
        }
      }
    }
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
    final currentTabIds = currentTabs.map((tab) => tab.id).toSet();
    _controllers.removeWhere((id, _) => !currentTabIds.contains(id));
    _awakeTabIds.removeWhere((id) => !currentTabIds.contains(id));
  }

  /// Pushes updated theme/dark-mode settings to every live WebView controller.
  /// Called whenever themeProvider changes so ALL tabs (not just the active one)
  /// immediately reflect the new Light/Dark/System mode.
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
          securityState.isAdBlockEnabled ? AdBlockService.adBlockRules : [],
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

    for (final controller in _controllers.values) {
      try {
        await controller.setSettings(settings: settings);
      } catch (e) {
        debugPrint("Theme sync safe fail: $e");
      }
    }
  }

  /// Lightweight stand-in for a hibernated tab.
  /// Shown for a brief moment while the fresh InAppWebView initialises after wake.
  Widget _buildHibernatedPlaceholder(BrowserTab tab) {
    return Container(
      color: Colors.black,
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

  /// Shows a bottom-sheet context menu when the user long-presses a link.
  void _showLinkContextMenu(String linkUrl) {
    if (!mounted) return;
    final theme = ref.read(themeProvider);
    final isGhost = ref.read(isGhostModeProvider);
    final isLight = theme.mode == ThemeMode.light;
    final textColor = isLight ? Colors.black87 : Colors.white;

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
            // URL preview pill
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

  /// Calculates the actual URL to load, applying the iOS Proxy Gateway if needed.
  String _getEffectiveUrl(String originalUrl, SecurityState security) {
    if (originalUrl.isEmpty) return originalUrl;
    
    final gateway = ref.read(proxyGatewayProvider);
    if (!kIsWeb && Platform.isIOS && security.isProxyEnabled && gateway.isRunning) {
      // Don't proxy the proxy itself
      if (originalUrl.startsWith('http://localhost')) return originalUrl;
      return gateway.getProxiedUrl(originalUrl);
    }
    return originalUrl;
  }

  @override
  Widget build(BuildContext context) {
    // 1. Watch Data
    final isGhost = ref.watch(isGhostModeProvider);
    final tabsState = isGhost ? ref.watch(ghostTabsProvider) : ref.watch(tabsProvider);
    final tabs = tabsState.tabs;
    final activeIndex = tabsState.activeIndex;
    final activeTabId = tabs.isNotEmpty ? tabs[activeIndex].id : '';

    ref.listen(tabsProvider, (previous, next) {
      if (!isGhost) {
        _cleanUpClosedTabs(next.tabs);
        if (previous?.activeIndex != next.activeIndex && next.tabs.isNotEmpty) {
          final newActiveId = next.tabs[next.activeIndex].id;
          _wakeTab(newActiveId);
          _updateControllersPauseState(newActiveId);
        }
      }
    });

    ref.listen(ghostTabsProvider, (previous, next) {
      if (isGhost) {
        _cleanUpClosedTabs(next.tabs);
        if (previous?.activeIndex != next.activeIndex && next.tabs.isNotEmpty) {
          final newActiveId = next.tabs[next.activeIndex].id;
          _wakeTab(newActiveId);
          _updateControllersPauseState(newActiveId);
        }
      }
    });

    // When the user switches between ghost and normal mode, wake the active tab
    // in the newly-visible set so it renders as a live WebView immediately.
    ref.listen(isGhostModeProvider, (_, isGhostNow) {
      final switchedState = isGhostNow
          ? ref.read(ghostTabsProvider)
          : ref.read(tabsProvider);
      if (switchedState.tabs.isNotEmpty) {
        _wakeTab(switchedState.tabs[switchedState.activeIndex].id);
      }
    });
    
    final securityState = ref.watch(securityProvider);

    // Listen to security state specifically to trigger proxy updates
    ref.listen(securityProvider, (previous, next) {
      if (previous?.isProxyEnabled != next.isProxyEnabled || previous?.proxyUrl != next.proxyUrl) {
        _applyProxy(next);
      }
    });

    // Push theme changes to ALL open WebView controllers (not just the active tab).
    ref.listen(themeProvider, (_, next) => _applyThemeToAllControllers(next));

    final theme = ref.watch(themeProvider);
    final errorMessage = ref.watch(webErrorProvider);
    final progress = ref.watch(loadingProgressProvider);
    
    // [FIX] Only show loading if URL is not empty
    final activeTabUrl = tabs.isNotEmpty ? tabs[activeIndex].url : '';
    final bool isLoading = progress < 100 && activeTabUrl.isNotEmpty;

    // 2. Handle Error State (Global for active tab)
    if (errorMessage != null && tabs.isNotEmpty) {
      return CustomErrorScreen(
        error: errorMessage,
        url: tabs[activeIndex].url,
        onRetry: () {
          HapticFeedback.mediumImpact();
          ref.read(webErrorProvider.notifier).state = null;
          ref.read(webViewControllerProvider)?.reload();    
        },
      );
    }
    
    // 3. Determine Force Dark Mode
    final forceDarkSetting = (theme.mode == ThemeMode.light) 
        ? ForceDark.OFF 
        : (theme.mode == ThemeMode.dark ? ForceDark.ON : ForceDark.AUTO);

    return Stack(
      children: [
        IndexedStack(
          index: activeIndex,
          children: tabs.map((tab) {
            if (tab.url.isEmpty) {
              return const BrandingScreen();
            }

            // Tabs outside the LRU wake window are replaced with a featherweight
            // placeholder. Flutter disposes the old InAppWebView, freeing its
            // native memory. When the user switches back, _wakeTab() is called,
            // the placeholder is replaced with a fresh InAppWebView, and the
            // saved URL reloads automatically.
            if (!_awakeTabIds.contains(tab.id)) {
              return _buildHibernatedPlaceholder(tab);
            }

            return InAppWebView(
              key: ObjectKey(tab.id),
              initialUrlRequest: URLRequest(url: WebUri(_getEffectiveUrl(tab.url, securityState))),
              
              initialUserScripts: securityState.isAdBlockEnabled
                  ? UnmodifiableListView<UserScript>(AdBlockService.initialUserScripts)
                  : null,
                  
              initialSettings: InAppWebViewSettings(
                incognito: isGhost || securityState.isIncognito, 
                clearCache: isGhost || securityState.isIncognito,
                cacheMode: CacheMode.LOAD_DEFAULT, 
                
                contentBlockers: securityState.isAdBlockEnabled ? AdBlockService.adBlockRules : [],
                forceDark: forceDarkSetting,
                algorithmicDarkeningAllowed: (theme.mode == ThemeMode.dark),
                useHybridComposition: !kIsWeb && Platform.isAndroid,
                hardwareAcceleration: true, 
                userAgent: securityState.isDesktopMode 
                    ? "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" 
                    : null,
                preferredContentMode: securityState.isDesktopMode 
                    ? UserPreferredContentMode.DESKTOP 
                    : UserPreferredContentMode.MOBILE,
              ),
              shouldInterceptRequest: (controller, request) async {
                if (!securityState.isAdBlockEnabled) return null;
                final host = request.url.host;
                if (AdBlockService.blockedDomains.any((domain) => host.contains(domain))) {
                  return WebResourceResponse(
                    contentType: 'text/plain',
                    data: Uint8List(0),
                  );
                }
                return null;
              },
              onWebViewCreated: (controller) {
                _controllers[tab.id] = controller;

                if (tab.id == activeTabId) {
                  ref.read(webViewControllerProvider.notifier).state = controller;
                }
              },
              onCreateWindow: (controller, createWindowAction) async {
                final url = createWindowAction.request.url;
                if (url == null || url.toString().isEmpty || url.toString() == 'about:blank') {
                  return true; 
                }
                HapticFeedback.lightImpact(); 
                if (isGhost) {
                  ref.read(ghostTabsProvider.notifier).addTab(url: url.toString());
                } else {
                  ref.read(tabsProvider.notifier).addTab(url: url.toString());
                }
                return true;
              },
              onLoadStart: (controller, url) {
                 if (tab.id == activeTabId) {
                   ref.read(webErrorProvider.notifier).state = null;
                 }
                 if (url != null) {
                   final urlString = url.toString();
                   // Avoid updating tab URL with the localhost proxy prefix
                   final displayUrl = urlString.contains('localhost') && urlString.contains('/http') 
                       ? urlString.split('/http').last.replaceFirst('s:', 'https:').replaceFirst(':', 'http:')
                       : urlString;

                   if (isGhost) {
                     ref.read(ghostTabsProvider.notifier).updateUrl(displayUrl);
                   } else {
                     ref.read(tabsProvider.notifier).updateUrl(displayUrl);
                   }
                 }
              },
              onProgressChanged: (controller, p) {
                if (tab.id == activeTabId) {
                  ref.read(loadingProgressProvider.notifier).state = p;
                }
              },
              onLoadStop: (controller, url) {
                  if (url != null) {
                    if (isGhost) {
                      ref.read(ghostTabsProvider.notifier).updateUrl(url.toString());
                    } else {
                      ref.read(tabsProvider.notifier).updateUrl(url.toString());
                    }

                    if (isGhost || securityState.isIncognito) {
                      if (!kIsWeb && Platform.isAndroid) {
                        // ignore: deprecated_member_use
                        WebStorageManager.instance().android.deleteAllData();
                      } else {
                        WebStorageManager.instance().deleteAllData();
                      }
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
                   if (tab.id == activeTabId) {
                     ref.read(webErrorProvider.notifier).state = error.description;
                   }
                }
              },
              onReceivedHttpError: (controller, request, response) {
                if (request.isForMainFrame ?? true) {
                   final code = response.statusCode;
                   if (code != null && code >= 400 && code != 403) {
                     if (tab.id == activeTabId) {
                       ref.read(webErrorProvider.notifier).state = "HTTP Error: $code";
                     }
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
                  HapticFeedback.mediumImpact();
                  await ref.read(downloadsProvider.notifier).startDownload(
                    downloadRequest.url.toString(),
                    filename: downloadRequest.suggestedFilename,
                  );
              },
              onLongPressHitTestResult: (controller, hitTestResult) async {
                final url = hitTestResult.extra;
                if (url != null && url.isNotEmpty &&
                    (hitTestResult.type ==
                            InAppWebViewHitTestResultType.SRC_ANCHOR_TYPE ||
                        hitTestResult.type ==
                            InAppWebViewHitTestResultType
                                .SRC_IMAGE_ANCHOR_TYPE)) {
                  HapticFeedback.mediumImpact();
                  _showLinkContextMenu(url);
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
            );
          }).toList(),
        ),

        // Skeleton Loader Overlay
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
}