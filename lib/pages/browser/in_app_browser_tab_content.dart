import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mira/core/entities/theme_entity.dart';
import 'package:mira/core/entities/security_entity.dart';
import 'package:mira/core/entities/tab_entity.dart';
import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/security_notifier.dart';
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/core/services/download_provider.dart';
import 'package:mira/pages/branding_screen.dart';
import 'package:mira/pages/browser_chrome_providers.dart';
import 'package:mira/shell/ad_block/ad_block_service_webview.dart';
import 'package:mira/shell/proxy/proxy_provider.dart';

import 'effective_request_url.dart';
import 'hibernated_tab_placeholder.dart';
import 'link_context_menu.dart';
import 'desktop_link_context_menu.dart';
import 'webview_constants.dart';
import 'webview_platform.dart';
import 'webview_session.dart';

/// One tab’s web surface: new tab branding, hibernation placeholder, or [InAppWebView].
Widget buildBrowserTabContent({
  required BuildContext context,
  required WidgetRef ref,
  required WebViewSession session,
  required BrowserTab tab,
  required String activeTabId,
  required bool isGhost,
  required Set<String> awakeTabIds,
  required SecurityState securityState,
  required MiraTheme theme,
  required ForceDark forceDarkSetting,
  required bool Function() isMounted,
}) {
  if (tab.url.isEmpty) {
    return const BrandingScreen();
  }
  if (!awakeTabIds.contains(tab.id)) {
    return HibernatedTabPlaceholder(tab: tab);
  }

  final findCtrl = browserWebViewSupportsNativeFindInteraction()
      ? session.findControllers.putIfAbsent(
          tab.id,
          () => FindInteractionController(),
        )
      : null;

  final effectiveUrl =
      effectiveBrowserUrl(tab.url, ref, securityState);

  return InAppWebView(
    key: ObjectKey(tab.id),
    initialUrlRequest:
        session.stableInitialUrlRequest(tab.id, effectiveUrl),
    contextMenu: buildDesktopLinkContextMenu(
      session,
      (url) => BrowserLinkContextMenu.show(
        context,
        ref,
        url,
        pointerPosition: session.lastPointerPosition,
      ),
    ),
    findInteractionController: findCtrl,
    initialUserScripts: securityState.isAdBlockEnabled
        ? kBrowserAdBlockUserScripts
        : null,
    initialSettings: session.stableWebSettings(
      isGhost: isGhost,
      securityState: securityState,
      theme: theme,
      forceDarkSetting: forceDarkSetting,
    ),
    shouldInterceptRequest: session.stableShouldInterceptRequest ??=
        (controller, request) async {
      if (!ref.read(securityProvider).isAdBlockEnabled) return null;
      final host = request.url.host;
      if (AdBlockServiceWebview.blockedDomains
          .any((domain) => host.contains(domain))) {
        return WebResourceResponse(
          contentType: 'text/plain',
          data: Uint8List(0),
        );
      }
      return null;
    },
    onWebViewCreated: (controller) {
      session.controllers[tab.id] = controller;
      final isGhostNow = ref.read(isGhostModeProvider);
      final currentState = isGhostNow
          ? ref.read(ghostTabsProvider)
          : ref.read(tabsProvider);
      final currentActiveId = currentState.tabs.isNotEmpty
          ? currentState.tabs[currentState.activeIndex].id
          : '';
      if (tab.id == currentActiveId) {
        session.webviewJustCreatedForTabId = tab.id;
        final n = ref.read(browserChromeProvider.notifier);
        n.setLoadingProgress(0);
        n.setController(controller);
        ref.read(activeFindInteractionProvider.notifier).state =
            browserWebViewSupportsNativeFindInteraction()
                ? session.findControllers[tab.id]
                : null;
      }
    },
    onCreateWindow: (controller, createWindowAction) async {
      final url = createWindowAction.request.url;
      if (url == null ||
          url.toString().isEmpty ||
          url.toString() == 'about:blank') {
        return true;
      }
      if (isGhost) {
        ref.read(ghostTabsProvider.notifier).addTab(url: url.toString());
      } else {
        ref.read(tabsProvider.notifier).addTab(url: url.toString());
      }
      return true;
    },
    onDownloadStartRequest: (controller, request) {
      final url = request.url.toString();
      debugPrint('MIRA_DOWNLOAD: Requested -> $url');
      ref.read(downloadsProvider.notifier).startDownload(
            url,
            filename: request.suggestedFilename,
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Download started: ${request.suggestedFilename ?? "file"}'),
          backgroundColor: Colors.blueAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    },
    onLoadStart: (controller, url) {
      session.lastProgressByTabId[tab.id] = 0;
      if (tab.id == activeTabId) {
        ref.read(browserChromeProvider.notifier).clearWebError();
        session.armSkeletonDismissTimer(
          tab.id,
          ref,
          isMounted: isMounted,
        );
      }
      if (url != null) {
        final urlString = url.toString();
        final gatewayTarget =
            ref.read(proxyServiceProvider).decodeGatewayEmbeddedTarget(urlString);
        final displayUrl = gatewayTarget ??
            (urlString.contains('localhost') && urlString.contains('/http')
                ? urlString
                    .split('/http')
                    .last
                    .replaceFirst('s:', 'https:')
                    .replaceFirst(':', 'http:')
                : urlString);
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
      session.lastProgressByTabId[tab.id] = p;
      if (tab.id == activeTabId) {
        ref.read(browserChromeProvider.notifier).setLoadingProgress(p);
      }
    },
    onLoadStop: (controller, url) {
      session.lastProgressByTabId[tab.id] = 100;
      if (tab.id == activeTabId) {
        session.cancelSkeletonDismissTimer();
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
          ref
              .read(browserChromeProvider.notifier)
              .setWebError(error.description);
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
