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
    final activeTab = ref.watch(currentActiveTabProvider);
    final activeUrl = activeTab.url;
    final isGhost = ref.watch(isGhostModeProvider);
    final securityState = ref.watch(securityProvider);
    final theme = ref.watch(themeProvider);
    final errorMessage = ref.watch(webErrorProvider);
    final progress = ref.watch(loadingProgressProvider);
    final bool isLoading = progress < 100;

    // 2. Handle Empty State
    if (activeUrl.isEmpty) {
      return const BrandingScreen();
    }

    // 3. Handle Error State
    if (errorMessage != null) {
      return CustomErrorScreen(
        error: errorMessage,
        url: activeUrl,
        onRetry: () {
          HapticFeedback.mediumImpact();
          ref.read(webErrorProvider.notifier).state = null;
          ref.read(webViewControllerProvider)?.reload();    
        },
      );
    }
    
    // 4. Determine Force Dark Mode
    final forceDarkSetting = (theme.mode == ThemeMode.light) 
        ? ForceDark.OFF 
        : (theme.mode == ThemeMode.dark ? ForceDark.ON : ForceDark.AUTO);

    return Stack(
      children: [
        InAppWebView(
          key: ValueKey("${isGhost ? 'G' : 'N'}_${activeTab.id}"),
          initialUrlRequest: URLRequest(url: WebUri(activeUrl)),
          initialSettings: InAppWebViewSettings(
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
          ),
          onWebViewCreated: (controller) {
            ref.read(webViewControllerProvider.notifier).state = controller;
          },
          onCreateWindow: (controller, createWindowAction) async {
            final url = createWindowAction.request.url;
            if (url == null || url.toString().isEmpty || url.toString() == 'about:blank') {
              return true; 
            }
            HapticFeedback.lightImpact(); 
            final isGhost = ref.read(isGhostModeProvider);
            if (isGhost) {
              ref.read(ghostTabsProvider.notifier).add(url: url.toString());
            } else {
              ref.read(tabsProvider.notifier).add(url: url.toString());
            }
            return true;
          },
          onLoadStart: (controller, url) {
             ref.read(webErrorProvider.notifier).state = null;
             if (url != null) {
               if (isGhost) {
                 ref.read(ghostTabsProvider.notifier).updateUrl(url.toString());
               } else {
                 ref.read(tabsProvider.notifier).updateUrl(url.toString());
               }
             }
          },
          onProgressChanged: (controller, progress) {
            ref.read(loadingProgressProvider.notifier).state = progress;
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
            // Ignore common network switching errors
            if (error.description.contains("net::ERR_ABORTED") || 
                error.description.contains("net::ERR_NETWORK_CHANGED") ||
                error.description.contains("net::ERR_INTERNET_DISCONNECTED")) {
               return; 
            }
            if (request.isForMainFrame ?? true) {
               ref.read(webErrorProvider.notifier).state = error.description;
            }
          },
          onReceivedHttpError: (controller, request, response) {
            if (request.isForMainFrame ?? true) {
               if (response.statusCode! >= 400 && response.statusCode != 403) {
                 ref.read(webErrorProvider.notifier).state = "HTTP Error: ${response.statusCode}";
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