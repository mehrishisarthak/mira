import 'dart:collection'; // Required for UnmodifiableListView
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart'; 

import 'package:mira/model/ad_block_model.dart';
import 'package:mira/model/download_model.dart';
import 'package:mira/model/theme_model.dart';
import 'package:mira/model/ghost_model.dart';
import 'package:mira/model/security_model.dart'; 
import 'package:mira/model/tab_model.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controllers.clear(); // Drop all references on complete disposal
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Optimization: Pause all WebViews when app is backgrounded
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      for (var controller in _controllers.values) {
        controller.pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      // Resume only the active tab's controller
      final isGhost = ref.read(isGhostModeProvider);
      final tabsState = isGhost ? ref.read(ghostTabsProvider) : ref.read(tabsProvider);
      if (tabsState.tabs.isNotEmpty) {
        final activeTabId = tabsState.tabs[tabsState.activeIndex].id;
        _controllers[activeTabId]?.resume();
      }
    }
  }

  void _updateControllersPauseState(String activeTabId) {
    _controllers.forEach((id, controller) {
      if (id == activeTabId) {
        controller.resume();
      } else {
        controller.pause();
      }
    });
  }

  // [NEW] Memory Management: Clean up controllers for tabs that were closed
  void _cleanUpClosedTabs(List<dynamic> currentTabs) {
    final currentTabIds = currentTabs.map((tab) => tab.id).toSet();
    _controllers.removeWhere((id, controller) {
      final isClosed = !currentTabIds.contains(id);
      return isClosed;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Watch Data
    final isGhost = ref.watch(isGhostModeProvider);
    final tabsState = isGhost ? ref.watch(ghostTabsProvider) : ref.watch(tabsProvider);
    final tabs = tabsState.tabs;
    final activeIndex = tabsState.activeIndex;
    final activeTabId = tabs.isNotEmpty ? tabs[activeIndex].id : '';

    // Listen safely to tab changes to update pause states AND clean up closed tabs
    ref.listen(tabsProvider, (previous, next) {
      if (!isGhost) {
        _cleanUpClosedTabs(next.tabs);
        if (previous?.activeIndex != next.activeIndex && next.tabs.isNotEmpty) {
           _updateControllersPauseState(next.tabs[next.activeIndex].id);
        }
      }
    });

    ref.listen(ghostTabsProvider, (previous, next) {
      if (isGhost) {
        _cleanUpClosedTabs(next.tabs);
        if (previous?.activeIndex != next.activeIndex && next.tabs.isNotEmpty) {
           _updateControllersPauseState(next.tabs[next.activeIndex].id);
        }
      }
    });
    
    final securityState = ref.watch(securityProvider);
    final theme = ref.watch(themeProvider);
    final errorMessage = ref.watch(webErrorProvider);
    final progress = ref.watch(loadingProgressProvider);
    final bool isLoading = progress < 100;

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
            // Only show BrandingScreen if the active tab is empty and it's the current active tab
            if (tab.url.isEmpty) {
              return const BrandingScreen();
            }

            return InAppWebView(
              // Unique key per tab to keep its state alive in the IndexedStack
              key: ObjectKey(tab.id),
              initialUrlRequest: URLRequest(url: WebUri(tab.url)),
              
              // [FIX] Safely wrap UserScripts in UnmodifiableListView to satisfy v6+ strict typing
              initialUserScripts: (securityState.isAdBlockEnabled) 
                  ? UnmodifiableListView<UserScript>(AdBlockService.initialUserScripts) 
                  : null,
                  
              initialSettings: InAppWebViewSettings(
                incognito: isGhost || securityState.isIncognito, 
                clearCache: isGhost || securityState.isIncognito,
                cacheMode: CacheMode.LOAD_DEFAULT, 
                contentBlockers: securityState.isAdBlockEnabled ? AdBlockService.adBlockRules : [],
                forceDark: forceDarkSetting,
                algorithmicDarkeningAllowed: (theme.mode == ThemeMode.dark),
                useHybridComposition: true,
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
                   if (isGhost) {
                     ref.read(ghostTabsProvider.notifier).updateUrl(url.toString());
                   } else {
                     ref.read(tabsProvider.notifier).updateUrl(url.toString());
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
                      // ignore: deprecated_member_use
                      WebStorageManager.instance().android.deleteAllData();
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
                   if (response.statusCode! >= 400 && response.statusCode != 403) {
                     if (tab.id == activeTabId) {
                       ref.read(webErrorProvider.notifier).state = "HTTP Error: ${response.statusCode}";
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