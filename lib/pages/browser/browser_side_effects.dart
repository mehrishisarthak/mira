import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/app_globals.dart';
import 'package:mira/core/entities/tab_entity.dart';
import 'package:mira/pages/downloads_screen.dart';

import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/history_notifier.dart';
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/core/notifiers/hibernation_notifier.dart';
import 'package:mira/core/notifiers/theme_notifier.dart';
import 'package:mira/core/services/database_providers.dart';
import 'package:mira/core/services/browser_engine_blueprints.dart';
import 'package:mira/core/services/download_provider.dart';
import 'package:mira/pages/browser_chrome_providers.dart';
import 'package:mira/pages/main_screen/main_screen_security.dart';

/// Provider that manages the stream subscription for a given [BrowserEngine].
/// autoDispose so the family entry — and its `pageEvents` subscription — is torn
/// down once the engine is de-activated (no longer watched). Without autoDispose
/// the family caches one live subscription per engine ever activated, leaking
/// across tab churn even though the onDispose teardown below was already correct.
final _engineEventsSubscriptionProvider =
    Provider.autoDispose.family<void, BrowserEngine>((ref, engine) {
  final subscription = engine.pageEvents.listen((event) {
    handleEnginePageEvent(ref, event);
  });

  ref.onDispose(() {
    subscription.cancel();
  });
});

/// Translates a single engine [BrowserPageEvent] into chrome/tab/history state
/// updates. Extracted from the subscription closure so the mapping can be
/// unit-tested with a [ProviderContainer] — no live webview required.
@visibleForTesting
void handleEnginePageEvent(Ref ref, BrowserPageEvent event) {
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
        // Record on loadStop (not only titleChanged) so pages that never
        // change their title — error pages, PDFs, many SPAs — still land in
        // history. Keyed off the event's own url, immune to a tab switch.
        _recordHistory(ref, event.url!);
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
        _updateHistoryTitle(ref, event.url, event.title!);
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
        _showDownloadStartedSnackBar(req.filename);
      }
      break;
  }
}

Map<String, String>? _parseHeaders(String? cookies) {
  if (cookies == null || cookies.isEmpty) return null;
  return {'Cookie': cookies};
}

/// Chrome-style "download started" snackbar with a shortcut to the Downloads
/// screen. Shown from the page-event handler, which has no [BuildContext], so it
/// drives the UI through the app-global keys.
void _showDownloadStartedSnackBar(String? filename) {
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;
  final hasName = filename != null && filename.isNotEmpty;
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(hasName ? 'Downloading $filename' : 'Download started'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'VIEW',
          onPressed: () => rootNavigatorKey.currentState?.push(
            MaterialPageRoute<void>(builder: (_) => const DownloadsPage()),
          ),
        ),
      ),
    );
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

/// Records a completed navigation in history. Called on loadStop with the
/// event's own url so it is correct even if the active tab changed between the
/// native callback and this handler.
void _recordHistory(Ref ref, String url) {
  // Skip in ghost mode — history is not recorded.
  if (ref.read(isGhostModeProvider)) return;
  if (url.isEmpty || url == 'about:blank') return;
  // Title is the active tab's current title. Usually titleChanged fires before
  // loadStop, so this is the page's real title (and a later titleChanged refines
  // it). For image/PDF/no-<title> loads where NO titleChanged follows, it may be
  // stale (the prior page's title) and won't self-heal. The url — what matters
  // for revisiting — is always correct.
  final title = ref.read(tabsProvider).safeActiveTab?.title ?? '';
  ref.read(historyProvider.notifier).addToHistory(url, title: title);
}

/// Refines the title of the history entry for [url] (the page the title event
/// belongs to), not whichever tab happens to be active right now.
void _updateHistoryTitle(Ref ref, String? url, String title) {
  // Skip in ghost mode — history is not recorded.
  if (ref.read(isGhostModeProvider)) return;
  if (url == null || url.isEmpty || url == 'about:blank') return;
  ref.read(historyProvider.notifier).addToHistory(url, title: title);
}
