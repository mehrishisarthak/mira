
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/core/services/database_providers.dart';
import 'package:mira/core/services/browser_engine_blueprints.dart';
import 'package:mira/pages/browser_chrome_providers.dart';

void registerBrowserViewSideEffects({
  required WidgetRef ref,
  required bool Function() isMounted,
}) {
  // Sync active engine to BrowserChromeProvider
  ref.listen(tabsProvider, (previous, next) {
    if (!ref.read(isGhostModeProvider)) {
      _syncEngineToChrome(ref, next.tabs, next.activeIndex);
    }
  });

  ref.listen(ghostTabsProvider, (previous, next) {
    if (ref.read(isGhostModeProvider)) {
      _syncEngineToChrome(ref, next.tabs, next.activeIndex);
    }
  });

  ref.listen(isGhostModeProvider, (_, isGhostNow) {
    final state = isGhostNow ? ref.read(ghostTabsProvider) : ref.read(tabsProvider);
    _syncEngineToChrome(ref, state.tabs, state.activeIndex);
  });

  // Listen to active engine events
  final activeEngine = ref.watch(activeBrowserEngineProvider);
  if (activeEngine != null) {
    ref.listen(browserEngineProvider(ref.read(_activeTabIdProvider)), (prev, next) {
       // Handled by the stream subscription below
    });
    
    // Subscribe to page events
    _subscribeToEngineEvents(ref, activeEngine);
  }
}

final _activeTabIdProvider = Provider<String>((ref) {
  final isGhost = ref.watch(isGhostModeProvider);
  final state = isGhost ? ref.watch(ghostTabsProvider) : ref.watch(tabsProvider);
  return state.tabs.isNotEmpty ? state.tabs[state.activeIndex].id : '';
});

void _syncEngineToChrome(WidgetRef ref, List tabs, int index) {
  if (tabs.isEmpty) {
    ref.read(browserChromeProvider.notifier).setEngine(null);
    return;
  }
  final tabId = tabs[index].id;
  final engine = ref.read(browserEngineProvider(tabId));
  ref.read(browserChromeProvider.notifier).setEngine(engine);
}

void _subscribeToEngineEvents(WidgetRef ref, BrowserEngine engine) {
  engine.pageEvents.listen((event) {
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
        // Handoff to DownloadsNotifier/Manager
        break;
    }
  });
}

// --- FIX: Explicitly typed update methods ---

void _updateTabUrl(WidgetRef ref, String url) {
  final isGhost = ref.read(isGhostModeProvider);
  if (isGhost) {
    ref.read(ghostTabsProvider.notifier).updateUrl(url);
  } else {
    ref.read(tabsProvider.notifier).updateUrl(url);
  }
}

void _updateTabTitle(WidgetRef ref, String title) {
  final isGhost = ref.read(isGhostModeProvider);
  if (isGhost) {
    ref.read(ghostTabsProvider.notifier).updateTitle(title);
  } else {
    ref.read(tabsProvider.notifier).updateTitle(title);
  }
}