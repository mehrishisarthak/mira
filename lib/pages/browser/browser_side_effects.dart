import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/entities/tab_entity.dart';

import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/history_notifier.dart';
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
          _updateHistoryTitle(ref, event.title!);
        }
        break;
      case BrowserPageEventType.error:
        notifier.setWebError(event.errorDescription);
        break;
      case BrowserPageEventType.downloadRequested:
        if (event.downloadRequest != null) {
          final req = event.downloadRequest!;
          unawaited(
            ref.read(downloadsProvider.notifier).startDownload(
              req.url,
              filename: req.filename,
              headers: _parseHeaders(req.cookies),
            ).catchError((Object e) {
              debugPrint('MIRA_DOWNLOAD: event handler error -> $e');
            }),
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

/// Called once from [BrowserView.initState] after the first frame.
void syncInitialEngine(WidgetRef ref) {
  final isGhost = ref.read(isGhostModeProvider);
  final state = isGhost ? ref.read(ghostTabsProvider) : ref.read(tabsProvider);
  _syncEngineToChrome(ref, state.tabs, state.activeIndex);
}

void registerBrowserViewSideEffects({required WidgetRef ref}) {
  // 1. Sync active engine to BrowserChromeProvider and manage Hibernation
  ref.listen(tabsProvider, (previous, next) {
    if (!ref.read(isGhostModeProvider)) {
      _syncEngineToChrome(ref, next.tabs, next.activeIndex);
    }
    if (previous != null && previous.tabs.length > next.tabs.length) {
      final currentIds = next.tabs.map((t) => t.id).toSet();
      final closedIds = previous.tabs.map((t) => t.id).toSet().difference(currentIds);
      for (final id in closedIds) {
        ref.invalidate(browserEngineProvider(id));
      }
      ref.read(hibernationProvider.notifier).onTabsClosed(currentIds);
    }
  });

  ref.listen(ghostTabsProvider, (previous, next) {
    final isGhost = ref.read(isGhostModeProvider);
    if (isGhost && next.tabs.isEmpty) {
      ref.read(isGhostModeProvider.notifier).state = false;
      return;
    }
    if (isGhost) {
      _syncEngineToChrome(ref, next.tabs, next.activeIndex);
    }
    if (previous != null && previous.tabs.length > next.tabs.length) {
      final currentIds = next.tabs.map((t) => t.id).toSet();
      final closedIds = previous.tabs.map((t) => t.id).toSet().difference(currentIds);
      for (final id in closedIds) {
        ref.invalidate(browserEngineProvider(id));
      }
      ref.read(hibernationProvider.notifier).onTabsClosed(currentIds);
    }
  });

  ref.listen(isGhostModeProvider, (_, isGhostNow) {
    final state = isGhostNow ? ref.read(ghostTabsProvider) : ref.read(tabsProvider);
    _syncEngineToChrome(ref, state.tabs, state.activeIndex);
  });

  // 2. Listen to Theme changes to sync dark mode with the ACTIVE engine.
  // Security changes (desktop mode, camera, location, adblock) are handled
  // exclusively by mainscreen.dart's scoped listener to avoid double invocation.
  ref.listen(themeProvider, (_, __) {
    unawaited(applyMainScreenWebViewSettings(ref));
  });

  // 3. Subscribe to the active engine's events
  final activeEngine = ref.watch(activeBrowserEngineProvider);
  if (activeEngine != null) {
    ref.watch(_engineEventsSubscriptionProvider(activeEngine));
  }
}

void _syncEngineToChrome(WidgetRef ref, List<BrowserTab> tabs, int index) {
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
}

void _updateTabUrl(Ref ref, String url) {
  final isGhost = ref.read(isGhostModeProvider);
  if (isGhost) {
    ref.read(ghostTabsProvider.notifier).updateUrl(url);
  } else {
    ref.read(tabsProvider.notifier).updateUrl(url);
  }
}

void _updateTabTitle(Ref ref, String title) {
  final isGhost = ref.read(isGhostModeProvider);
  if (isGhost) {
    ref.read(ghostTabsProvider.notifier).updateTitle(title);
  } else {
    ref.read(tabsProvider.notifier).updateTitle(title);
  }
}

void _updateHistoryTitle(Ref ref, String title) {
  // Skip in ghost mode — history is not recorded
  if (ref.read(isGhostModeProvider)) return;
  final url = ref.read(tabsProvider).safeActiveTab?.url ?? '';
  if (url.isEmpty || url == 'about:blank') return;
  ref.read(historyProvider.notifier).addToHistory(url, title: title);
}
