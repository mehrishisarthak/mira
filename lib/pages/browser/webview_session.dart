import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mira/core/entities/theme_entity.dart';
import 'package:mira/core/entities/security_entity.dart';
import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/security_notifier.dart';
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/core/entities/tab_entity.dart';
import 'package:mira/core/notifiers/hibernation_notifier.dart';
import 'package:mira/pages/browser_chrome_providers.dart';
import 'package:mira/shell/ad_block/ad_block_service_webview.dart';

import 'webview_constants.dart';

/// Owns per-tab WebView controllers, memoized requests/settings, and timers.
/// Keeps [BrowserView] state small and mirrors the previous single-file behavior.
class WebViewSession {
  final Map<String, InAppWebViewController> controllers = {};
  final Map<String, FindInteractionController> findControllers = {};
  final Map<String, int> lastProgressByTabId = {};
  final Map<String, URLRequest> memoUrlRequestByTabId = {};
  final Map<String, String> memoEffectiveUrlByTabId = {};

  String? cachedWebSettingsSignature;
  InAppWebViewSettings? cachedWebSettings;
  ContextMenu? cachedDesktopContextMenu;

  Future<WebResourceResponse?> Function(
    InAppWebViewController controller,
    WebResourceRequest request,
  )? stableShouldInterceptRequest;

  Timer? skeletonDismissTimer;
  String? webviewJustCreatedForTabId;

  Offset? lastPointerPosition;
  DateTime? lastHorizontalWheelNavAt;

  void cancelSkeletonDismissTimer() {
    skeletonDismissTimer?.cancel();
    skeletonDismissTimer = null;
  }

  void armSkeletonDismissTimer(
    String tabIdWhenArmed,
    WidgetRef ref, {
    required bool Function() isMounted,
  }) {
    cancelSkeletonDismissTimer();
    skeletonDismissTimer = Timer(kWebViewSkeletonAutoDismiss, () {
      if (!isMounted()) return;
      final ghost = ref.read(isGhostModeProvider);
      final state =
          ghost ? ref.read(ghostTabsProvider) : ref.read(tabsProvider);
      if (state.tabs.isEmpty) return;
      final activeId = state.tabs[state.activeIndex].id;
      if (activeId != tabIdWhenArmed) return;
      ref.read(browserChromeProvider.notifier).setLoadingProgress(100);
    });
  }

  URLRequest stableInitialUrlRequest(String tabId, String effectiveUrl) {
    if (controllers.containsKey(tabId)) {
      final memo = memoUrlRequestByTabId[tabId];
      if (memo != null) return memo;
      final r = URLRequest(url: WebUri(effectiveUrl));
      memoUrlRequestByTabId[tabId] = r;
      memoEffectiveUrlByTabId[tabId] = effectiveUrl;
      return r;
    }
    if (memoEffectiveUrlByTabId[tabId] == effectiveUrl &&
        memoUrlRequestByTabId.containsKey(tabId)) {
      return memoUrlRequestByTabId[tabId]!;
    }
    memoEffectiveUrlByTabId[tabId] = effectiveUrl;
    final req = URLRequest(url: WebUri(effectiveUrl));
    memoUrlRequestByTabId[tabId] = req;
    return req;
  }

  InAppWebViewSettings stableWebSettings({
    required bool isGhost,
    required SecurityState securityState,
    required MiraTheme theme,
    required ForceDark forceDarkSetting,
  }) {
    final sig =
        '$isGhost|${securityState.isIncognito}|${securityState.isAdBlockEnabled}|'
        '${securityState.isDesktopMode}|${theme.mode}|$forceDarkSetting';
    if (cachedWebSettingsSignature == sig && cachedWebSettings != null) {
      return cachedWebSettings!;
    }
    cachedWebSettingsSignature = sig;
    cachedWebSettings = InAppWebViewSettings(
      incognito: isGhost || securityState.isIncognito,
      clearCache: isGhost || securityState.isIncognito,
      cacheMode: CacheMode.LOAD_DEFAULT,
      useOnDownloadStart: true,
      contentBlockers: securityState.isAdBlockEnabled
          ? AdBlockServiceWebview.contentBlockers
          : [],
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
    );
    return cachedWebSettings!;
  }

  void disposeFindControllers() {
    for (final c in findControllers.values) {
      try {
        c.dispose();
      } catch (_) {}
    }
    findControllers.clear();
  }

  void updateControllersPauseState(String activeTabId) {
    controllers.forEach((id, controller) {
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

  void cleanUpClosedTabs(List<dynamic> currentTabs, WidgetRef ref) {
    final currentTabIds = currentTabs.map((tab) => tab.id as String).toSet();
    final removedIds =
        controllers.keys.where((id) => !currentTabIds.contains(id)).toList();
    for (final id in removedIds) {
      lastProgressByTabId.remove(id);
      memoUrlRequestByTabId.remove(id);
      memoEffectiveUrlByTabId.remove(id);
      try {
        findControllers[id]?.dispose();
      } catch (_) {}
      findControllers.remove(id);
    }
    controllers.removeWhere((id, _) => !currentTabIds.contains(id));
    ref.read(hibernationProvider.notifier).onTabsClosed(currentTabIds);
  }

  Future<void> applyThemeToAllControllers(
      MiraTheme theme, WidgetRef ref) async {
    if (controllers.isEmpty) return;
    final securityState = ref.read(securityProvider);
    final isGhost = ref.read(isGhostModeProvider);

    final forceDarkSetting = (theme.mode == ThemeMode.light)
        ? ForceDark.OFF
        : (theme.mode == ThemeMode.dark ? ForceDark.ON : ForceDark.AUTO);

    final settings = InAppWebViewSettings(
      incognito: isGhost || securityState.isIncognito,
      clearCache: isGhost || securityState.isIncognito,
      cacheMode: CacheMode.LOAD_DEFAULT,
      useOnDownloadStart: true,
      contentBlockers: securityState.isAdBlockEnabled
          ? AdBlockServiceWebview.contentBlockers
          : [],
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
    );

    for (final controller in controllers.values) {
      try {
        await controller.setSettings(settings: settings);
      } catch (e) {
        debugPrint("Theme sync safe fail: $e");
      }
    }
  }

  void syncChromeToActiveWebView(
    BrowserTab active,
    WidgetRef ref, {
    bool updateProgress = true,
  }) {
    final awake = ref.read(hibernationProvider);
    final hasLiveWebView = active.url.isNotEmpty && awake.contains(active.id);
    final ctrl = hasLiveWebView ? controllers[active.id] : null;
    final chrome = ref.read(browserChromeProvider.notifier);
    chrome.setController(ctrl);
    if (!updateProgress) return;
    if (hasLiveWebView && ctrl != null) {
      if (webviewJustCreatedForTabId == active.id) {
        return;
      }
      final stored = lastProgressByTabId[active.id];
      chrome.setLoadingProgress(stored ?? 100);
    } else if (active.url.isEmpty) {
      chrome.setLoadingProgress(100);
    } else {
      chrome.setLoadingProgress(0);
    }
  }

  void onHibernationEvicted(Set<String> previous, Set<String> next) {
    for (final id in previous.difference(next)) {
      controllers.remove(id);
      lastProgressByTabId.remove(id);
      memoUrlRequestByTabId.remove(id);
      memoEffectiveUrlByTabId.remove(id);
      try {
        findControllers[id]?.dispose();
      } catch (_) {}
      findControllers.remove(id);
    }
  }
}

String? activeTabIdFromState(TabsState? state) {
  if (state == null || state.tabs.isEmpty) return null;
  final idx = state.activeIndex;
  if (idx < 0 || idx >= state.tabs.length) return null;
  return state.tabs[idx].id;
}
