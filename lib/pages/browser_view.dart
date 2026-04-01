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
import 'package:mira/shell/proxy/proxy_provider.dart'; 

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

  // ── LIFECYCLE ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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
    WidgetsBinding.instance.removeObserver(this);
    _controllers.clear();
    super.dispose();
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
    final isGatewayRunning = ref.watch(proxyGatewayStatusProvider);
    if (!kIsWeb && Platform.isIOS && security.isProxyEnabled && isGatewayRunning) {
      if (originalUrl.startsWith('http://localhost')) return originalUrl;
      return gateway.getProxiedUrl(originalUrl);
    }
    return originalUrl;
  }

  @override
  Widget build(BuildContext context) {
    final isGhost = ref.watch(isGhostModeProvider);
    final tabsState = isGhost ? ref.watch(ghostTabsProvider) : ref.watch(tabsProvider);
    final tabs = tabsState.tabs;
    final activeIndex = tabsState.activeIndex;
    final activeTabId = tabs.isNotEmpty ? tabs[activeIndex].id : '';
    
    final awakeTabIds = ref.watch(hibernationProvider);

    ref.listen(tabsProvider, (previous, next) {
      if (!isGhost) {
        _cleanUpClosedTabs(next.tabs);
        if (previous?.activeIndex != next.activeIndex && next.tabs.isNotEmpty) {
          final newActiveId = next.tabs[next.activeIndex].id;
          ref.read(hibernationProvider.notifier).wakeTab(newActiveId);
          _updateControllersPauseState(newActiveId);
        }
      }
    });

    ref.listen(ghostTabsProvider, (previous, next) {
      if (isGhost) {
        _cleanUpClosedTabs(next.tabs);
        if (previous?.activeIndex != next.activeIndex && next.tabs.isNotEmpty) {
          final newActiveId = next.tabs[next.activeIndex].id;
          ref.read(hibernationProvider.notifier).wakeTab(newActiveId);
          _updateControllersPauseState(newActiveId);
        }
      }
    });

    ref.listen(isGhostModeProvider, (_, isGhostNow) {
      final switchedState = isGhostNow
          ? ref.read(ghostTabsProvider)
          : ref.read(tabsProvider);
      if (switchedState.tabs.isNotEmpty) {
        final activeId = switchedState.tabs[switchedState.activeIndex].id;
        ref.read(hibernationProvider.notifier).wakeTab(activeId);
      }
    });
    
    final securityState = ref.watch(securityProvider);

    ref.listen(securityProvider, (previous, next) {
      if (previous?.isProxyEnabled != next.isProxyEnabled || previous?.proxyUrl != next.proxyUrl) {
        ref.read(browserServiceProvider).applyProxy(next);
      }
    });

    ref.listen(themeProvider, (_, next) => _applyThemeToAllControllers(next));

    final theme = ref.watch(themeProvider);
    final errorMessage = ref.watch(webErrorProvider);
    final progress = ref.watch(loadingProgressProvider);
    
    final activeTabUrl = tabs.isNotEmpty ? tabs[activeIndex].url : '';
    final bool isLoading = progress < 100 && activeTabUrl.isNotEmpty;

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

            if (!awakeTabIds.contains(tab.id)) {
              return _buildHibernatedPlaceholder(tab);
            }

            return InAppWebView(
              key: ObjectKey(tab.id),
              initialUrlRequest: URLRequest(url: WebUri(_getEffectiveUrl(tab.url, securityState))),
              
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



