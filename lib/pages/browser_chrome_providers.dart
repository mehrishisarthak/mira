import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/core/services/browser_engine_blueprints.dart';

/// Single source of truth for the active tab's BrowserEngine: engine handle,
/// top-level load progress (0–100), and main-frame error text.
@immutable
class BrowserChromeState {
  const BrowserChromeState({
    this.engine,
    this.loadingProgress = 0,
    this.webError,
  });

  final BrowserEngine? engine;
  final int loadingProgress;
  final String? webError;

  // NOTE: consulted only by `.select` consumers. The StateNotifier itself
  // notifies by identical(), and every setter allocates a fresh instance, so
  // this == never suppresses a notification — any *unscoped*
  // watch(browserChromeProvider) rebuilds on every progress tick. Always
  // `.select` the field you need.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BrowserChromeState &&
          identical(other.engine, engine) &&
          other.loadingProgress == loadingProgress &&
          other.webError == webError);

  @override
  int get hashCode =>
      Object.hash(identityHashCode(engine), loadingProgress, webError);
}

class BrowserChromeNotifier extends StateNotifier<BrowserChromeState> {
  BrowserChromeNotifier() : super(const BrowserChromeState());

  void setEngine(BrowserEngine? e) {
    state = BrowserChromeState(
      engine: e,
      loadingProgress: state.loadingProgress,
      webError: state.webError,
    );
  }

  void setLoadingProgress(int value) {
    state = BrowserChromeState(
      engine: state.engine,
      loadingProgress: value,
      webError: state.webError,
    );
  }

  void setWebError(String? value) {
    state = BrowserChromeState(
      engine: state.engine,
      loadingProgress: state.loadingProgress,
      webError: value,
    );
  }

  void clearWebError() {
    state = BrowserChromeState(
      engine: state.engine,
      loadingProgress: state.loadingProgress,
      webError: null,
    );
  }

  /// Drawer "nuke" and similar full resets.
  void resetSessionChrome() {
    state = const BrowserChromeState();
  }
}

final browserChromeProvider =
    StateNotifierProvider<BrowserChromeNotifier, BrowserChromeState>((ref) {
  return BrowserChromeNotifier();
});

/// Same as [BrowserChromeState.engine] — the live [BrowserEngine]
/// for the **current** tab.
final activeBrowserEngineProvider = Provider<BrowserEngine?>((ref) {
  return ref.watch(browserChromeProvider).engine;
});

final activeTabIdProvider = Provider<String>((ref) {
  final isGhost = ref.watch(isGhostModeProvider);
  final state = isGhost ? ref.watch(ghostTabsProvider) : ref.watch(tabsProvider);
  return state.tabs.isNotEmpty ? state.tabs[state.activeIndex].id : '';
});

final desktopFindBarVisibleProvider = StateProvider<bool>((ref) => false);

/// Screenshot of a specific tab's webview, captured when a Flutter overlay (the
/// tab sheet) opens over the live page. While set, [BrowserView] Offstages that
/// tab's live Hybrid-Composition surface and paints this image instead —
/// dropping the platform-view from the composite so the overlay animates
/// without the HC tax, while keeping the native view alive (no reload on
/// restore). Scoped by [tabId] so switching tabs from the sheet shows the new
/// tab live, not this stale screenshot. Null = show the live webview.
@immutable
class WebViewSnapshot {
  const WebViewSnapshot({required this.tabId, required this.bytes});
  final String tabId;
  final Uint8List bytes;
}

final webViewSnapshotProvider = StateProvider<WebViewSnapshot?>((ref) => null);
