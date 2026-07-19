import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qyx/core/notifiers/ghost_notifier.dart';
import 'package:qyx/core/notifiers/tab_notifier.dart';
import 'package:qyx/core/services/browser_engine_blueprints.dart';

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
    if (state.engine == e) return;
    state = BrowserChromeState(
      engine: e,
      loadingProgress: state.loadingProgress,
      webError: state.webError,
    );
  }

  void setLoadingProgress(int value) {
    if (state.loadingProgress == value) return;
    state = BrowserChromeState(
      engine: state.engine,
      loadingProgress: value,
      webError: state.webError,
    );
  }

  void setWebError(String? value) {
    if (state.webError == value) return;
    state = BrowserChromeState(
      engine: state.engine,
      loadingProgress: state.loadingProgress,
      webError: value,
    );
  }

  void clearWebError() {
    if (state.webError == null) return;
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
  return ref.watch(browserChromeProvider.select((s) => s.engine));
});

final activeTabIdProvider = Provider<String>((ref) {
  final isGhost = ref.watch(isGhostModeProvider);
  final tab = isGhost
      ? ref.watch(ghostTabsProvider.select((s) => s.safeActiveTab))
      : ref.watch(tabsProvider.select((s) => s.safeActiveTab));
  return tab?.id ?? '';
});

final desktopFindBarVisibleProvider = StateProvider<bool>((ref) => false);

/// Screenshot of a specific tab's webview, captured when a Flutter overlay (the
/// tab sheet) opens over the live page. While set, [BrowserView] paints this
/// image *over* that tab's live Hybrid-Composition surface, so the overlay
/// animates against a cheap Flutter texture instead of the page.
///
/// NOTE: the surface underneath is still mounted and still composited every
/// frame — Flutter does not occlusion-cull an opaque-covered platform view, so
/// the HC tax is masked, not dropped. Dropping it needs an `Offstage` around
/// the live child; that is tracked as **O-81** and is gated on a `--profile`
/// trace. `pauseRendering()` at the call site stops frame *production*, which
/// is a different saving. Do not read this doc as claiming the layer leaves
/// the composite.
///
/// Scoped by [tabId] so switching tabs from the sheet shows the new tab live,
/// not this stale screenshot. Null = show the live webview.
@immutable
class WebViewSnapshot {
  const WebViewSnapshot({required this.tabId, required this.bytes});
  final String tabId;
  final Uint8List bytes;
}

final webViewSnapshotProvider = StateProvider<WebViewSnapshot?>((ref) => null);

/// Cache of snapshots for hibernated tabs and the grid view. 
/// Uses a hybrid approach: ephemeral/ghost tabs use [bytes] (RAM),
/// while normal tabs use [diskPath] to prevent OOM crashes.
@immutable
class TabSnapshotData {
  final Uint8List? bytes;
  final String? diskPath;
  const TabSnapshotData({this.bytes, this.diskPath});
}

final tabSnapshotCacheProvider = StateProvider<Map<String, TabSnapshotData>>((ref) => {});
