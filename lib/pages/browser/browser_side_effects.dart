import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/core/notifiers/hibernation_notifier.dart';
import 'package:mira/core/notifiers/theme_notifier.dart';
import 'package:mira/core/notifiers/security_notifier.dart';
import 'package:mira/core/services/database_providers.dart';
import 'package:mira/core/services/browser_engine_blueprints.dart';
import 'package:mira/core/services/download_provider.dart';
import 'package:mira/pages/browser_chrome_providers.dart';
import 'package:mira/pages/main_screen/main_screen_security.dart';

/// Provider that manages the stream subscription for a given [BrowserEngine].
/// It ensures that we only have one listener per engine and that it's properly
/// disposed when the engine is no longer active or the provider is disposed.
final _engineEventsSubscriptionProvider = Provider.family<void, BrowserEngine>((ref, engine) {
  final subscription = engine.pageEvents.listen((event) {
    final notifier = ref.read(browserChromeProvider.notifier);
    switch (event.type) {
      case BrowserPageEventType.loadStart:
        notifier.clearWebError();
        notifier.setLoadingProgress(0);
        if (event.url != null) {
          _updateTabUrl(ref, event.url!);
        }
        break;
      case BrowserPageEventType.loadStop:
        notifier.setLoadingProgress(100);
        if (event.url != null) {
          _updateTabUrl(ref, event.url!);
        }
        break;
      case BrowserPageEventType.progressChanged:
        if (event.progress != null) {
          notifier.setLoadingProgress(event.progress!);
        }
        break;
      case BrowserPageEventType.titleChanged:
        if (event.title != null) {
          _updateTabTitle(ref, event.title!);
        }
        break;
      case BrowserPageEventType.error:
        notifier.setWebError(event.errorDescription);
        break;
      case BrowserPageEventType.downloadRequested:
        if (event.downloadRequest != null) {
          final req = event.downloadRequest!;
          ref.read(downloadsProvider.notifier).startDownload(
                req.url,
                filename: req.filename,
                headers: _parseHeaders(req.cookies),
              );
        }
        break;
    }
  });

  ref.onDispose(() {
    subscription.cancel();
  });
});

Map<String, String>? _parseHeaders(String? cookies) {
  if (cookies == null || cookies.isEmpty) return null;
  return {'Cookie': cookies};
}

void registerBrowserViewSideEffects({
  required WidgetRef ref,
  required bool Function() isMounted,
}) {
  // 0. Initial sync for the current state
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!isMounted()) return;
    final isGhost = ref.read(isGhostModeProvider);
    final state = isGhost ? ref.read(ghostTabsProvider) : ref.read(tabsProvider);
    _syncEngineToChrome(ref, state.tabs, state.activeIndex);
  });

  // 1. Sync active engine to BrowserChromeProvider and manage Hibernation
  ref.listen(tabsProvider, (previous, next) {
    if (!ref.read(isGhostModeProvider)) {
      _syncEngineToChrome(ref, next.tabs, next.activeIndex);
    }
    // Sync hibernation for closed tabs
    if (previous != null && previous.tabs.length > next.tabs.length) {
      ref.read(hibernationProvider.notifier).onTabsClosed(
        next.tabs.map((t) => t.id).toSet(),
      );
    }
  });

  ref.listen(ghostTabsProvider, (previous, next) {
    if (ref.read(isGhostModeProvider)) {
      _syncEngineToChrome(ref, next.tabs, next.activeIndex);
    }
    // Sync hibernation for closed tabs
    if (previous != null && previous.tabs.length > next.tabs.length) {
      ref.read(hibernationProvider.notifier).onTabsClosed(
        next.tabs.map((t) => t.id).toSet(),
      );
    }
  });

  ref.listen(isGhostModeProvider, (_, isGhostNow) {
    final state = isGhostNow ? ref.read(ghostTabsProvider) : ref.read(tabsProvider);
    _syncEngineToChrome(ref, state.tabs, state.activeIndex);
  });

  // 2. Listen to Theme & Security changes to sync with the ACTIVE engine
  ref.listen(themeProvider, (_, __) {
    applyMainScreenWebViewSettings(ref);
  });

  ref.listen(securityProvider, (_, __) {
    applyMainScreenWebViewSettings(ref);
  });

  // 3. Subscribe to the active engine's events
  final activeEngine = ref.watch(activeBrowserEngineProvider);
  if (activeEngine != null) {
    ref.watch(_engineEventsSubscriptionProvider(activeEngine));
  }
}

void _syncEngineToChrome(dynamic ref, List tabs, int index) {
  if (tabs.isEmpty) {
    ref.read(browserChromeProvider.notifier).setEngine(null);
    return;
  }
  final tabId = tabs[index].id;
  
  // CRITICAL: Wake up the active tab so BrowserView renders it
  ref.read(hibernationProvider.notifier).wakeTab(tabId);
  
  final engine = ref.read(browserEngineProvider(tabId));
  final chromeNotifier = ref.read(browserChromeProvider.notifier);
  chromeNotifier.setEngine(engine);
  chromeNotifier.setLoadingProgress(engine.lastProgress);

  // Apply current settings to this engine as it becomes active
  applyMainScreenWebViewSettings(ref);
}

void _updateTabUrl(dynamic ref, String url) {
  final isGhost = ref.read(isGhostModeProvider);
  if (isGhost) {
    ref.read(ghostTabsProvider.notifier).updateUrl(url);
  } else {
    ref.read(tabsProvider.notifier).updateUrl(url);
  }
}

void _updateTabTitle(dynamic ref, String title) {
  final isGhost = ref.read(isGhostModeProvider);
  if (isGhost) {
    ref.read(ghostTabsProvider.notifier).updateTitle(title);
  } else {
    ref.read(tabsProvider.notifier).updateTitle(title);
  }
}
