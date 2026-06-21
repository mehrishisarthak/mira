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
