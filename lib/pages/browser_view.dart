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

class BrowserView extends ConsumerWidget {
  const BrowserView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Watch Data
    final isGhost = ref.watch(isGhostModeProvider);
    final tabsState = isGhost ? ref.watch(ghostTabsProvider) : ref.watch(tabsProvider);
    final tabs = tabsState.tabs;
    final activeIndex = tabsState.activeIndex;
    
    final securityState = ref.watch(securityProvider);
    final theme = ref.watch(themeProvider);
    final errorMessage = ref.watch(webErrorProvider);
    final progress = ref.watch(loadingProgressProvider);
    final bool isLoading = progress < 100;

    // 2. Handle Error State (Global for active tab)
    if (errorMessage != null) {
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
              initialUserScripts: securityState.isAdBlockEnabled 
                  ? AdBlockService.initialUserScripts 
                  : null,
              initialSettings: InAppWebViewSettings(
                incognito: isGhost || securityState.isIncognito, 
                clearCache: isGhost || securityState.isIncognito,
                contentBlockers: securityState.isAdBlockEnabled ? AdBlockService.adBlockRules : [],
                forceDark: forceDarkSetting,
                algorithmicDarkeningAllowed: (theme.mode == ThemeMode.dark),
                useHybridComposition: true,
                hardwareAcceleration: true, // [NEW] Explicitly enable
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
                // Only set the global provider if this is the active tab
                if (tabs.indexOf(tab) == activeIndex) {
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
                 if (tabs.indexOf(tab) == activeIndex) {
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
                if (tabs.indexOf(tab) == activeIndex) {
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
                  }
              },
              onReceivedError: (controller, request, error) {
                if (error.description.contains("net::ERR_ABORTED") || 
                    error.description.contains("net::ERR_NETWORK_CHANGED") ||
                    error.description.contains("net::ERR_INTERNET_DISCONNECTED")) {
                   return; 
                }
                if (request.isForMainFrame ?? true) {
                   if (tabs.indexOf(tab) == activeIndex) {
                     ref.read(webErrorProvider.notifier).state = error.description;
                   }
                }
              },
              onReceivedHttpError: (controller, request, response) {
                if (request.isForMainFrame ?? true) {
                   if (response.statusCode! >= 400 && response.statusCode != 403) {
                     if (tabs.indexOf(tab) == activeIndex) {
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