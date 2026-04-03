import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Single source of truth for the active tab's WebView chrome: controller handle,
/// top-level load progress (0–100), and main-frame error text.
///
/// [BrowserView] owns tab ↔ chrome synchronization (hibernation, per-tab progress
/// maps, etc.); other features read this notifier instead of scattered
/// [StateProvider]s.
@immutable
class BrowserChromeState {
  const BrowserChromeState({
    this.controller,
    this.loadingProgress = 0,
    this.webError,
  });

  final InAppWebViewController? controller;
  final int loadingProgress;
  final String? webError;
}

class BrowserChromeNotifier extends StateNotifier<BrowserChromeState> {
  BrowserChromeNotifier() : super(const BrowserChromeState());

  void setController(InAppWebViewController? c) {
    state = BrowserChromeState(
      controller: c,
      loadingProgress: state.loadingProgress,
      webError: state.webError,
    );
  }

  void setLoadingProgress(int value) {
    state = BrowserChromeState(
      controller: state.controller,
      loadingProgress: value,
      webError: state.webError,
    );
  }

  void setWebError(String? value) {
    state = BrowserChromeState(
      controller: state.controller,
      loadingProgress: state.loadingProgress,
      webError: value,
    );
  }

  void clearWebError() {
    state = BrowserChromeState(
      controller: state.controller,
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

/// Active tab's [FindInteractionController] for "Find in page" (desktop).
final activeFindInteractionProvider =
    StateProvider<FindInteractionController?>((ref) => null);

/// Persistent bottom find bar (desktop); dialog path removed.
final desktopFindBarVisibleProvider = StateProvider<bool>((ref) => false);
