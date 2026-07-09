import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:mira/core/entities/tab_entity.dart';
import 'package:mira/core/services/preferences_service.dart';
import 'package:mira/core/services/snapshot_service.dart';

// --- 1. THE STATE CLASS ---
class TabsState {
  final List<BrowserTab> tabs;
  final int activeIndex;

  TabsState({required this.tabs, required this.activeIndex});

  BrowserTab get activeTab {
    if (tabs.isEmpty) {
      throw StateError('TabsState has no tabs');
    }
    final i = activeIndex.clamp(0, tabs.length - 1);
    return tabs[i];
  }

  /// Used when a session may have zero tabs (ghost/private before first tab).
  BrowserTab? get safeActiveTab {
    if (tabs.isEmpty) return null;
    final i = activeIndex.clamp(0, tabs.length - 1);
    return tabs[i];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TabsState &&
          other.activeIndex == activeIndex &&
          listEquals(other.tabs, tabs));

  @override
  int get hashCode => Object.hash(activeIndex, Object.hashAll(tabs));
}

// --- 2. THE NOTIFIER ---
class TabsNotifier extends StateNotifier<TabsState> {
  final PreferencesService _prefsService;
  final SnapshotService? _snapshotService;
  Timer? _saveDebounce;

  TabsNotifier(this._prefsService, {SnapshotService? snapshotService}) 
      : _snapshotService = snapshotService,
        super(TabsState(tabs: [BrowserTab()], activeIndex: 0)) {
    _loadTabs();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  void _loadTabs() {
    final savedJsonList = _prefsService.getSavedTabs();
    final savedIndex = _prefsService.getActiveTabIndex();
    if (savedJsonList.isNotEmpty) {
      try {
        final loadedTabs = savedJsonList
            .map((str) => BrowserTab.fromJson(str))
            .toList();
        int safeIndex = savedIndex;
        if (safeIndex < 0 || safeIndex >= loadedTabs.length) {
          safeIndex = 0;
        }
        var nextTabs = loadedTabs;
        var nextIndex = safeIndex;
        var didPrependFreshDial = false;
        final isDesktop = !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.windows ||
                defaultTargetPlatform == TargetPlatform.macOS ||
                defaultTargetPlatform == TargetPlatform.linux);
        if (isDesktop &&
            loadedTabs.isNotEmpty &&
            loadedTabs[safeIndex].url.isNotEmpty) {
          nextTabs = [BrowserTab(), ...loadedTabs];
          nextIndex = 0;
          didPrependFreshDial = true;
        }
        state = TabsState(tabs: nextTabs, activeIndex: nextIndex);
        if (didPrependFreshDial) {
          unawaited(_saveToPrefs());
        }
      } catch (e, stack) {
        debugPrint('[MIRA] TabNotifier corrupted data: $e\n$stack');
        state = TabsState(
          tabs: [BrowserTab(id: const Uuid().v4())],
          activeIndex: 0,
        );
      }
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final jsonList = state.tabs.map((tab) => tab.toJson()).toList();
      await _prefsService.saveTabs(jsonList, state.activeIndex);
    } catch (e) {
      debugPrint('[MIRA] TabNotifier: failed to persist tab state: $e');
    }
  }

  // Debounced save for high-frequency WebView events (URL/title updates).
  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () => unawaited(_saveToPrefs()));
  }

  /// Force an immediate write of any pending debounced save. Called on app
  /// pause/detach so a url/title change still inside the 500 ms debounce window
  /// isn't lost if the OS kills the process before the timer fires (O-11).
  Future<void> flush() async {
    if (!(_saveDebounce?.isActive ?? false)) return;
    _saveDebounce?.cancel();
    await _saveToPrefs();
  }

  // --- ACTIONS ---

  void addTab({String url = ''}) {
    // If the only existing tab is a blank seed tab and no URL is being opened,
    // reuse it rather than stacking a second blank tab on top. This prevents
    // the tab sheet's "no tabs" empty-state message from hiding the seed tab
    // and then revealing it alongside a new blank tab when the user taps "+".
    if (url.isEmpty && state.tabs.length == 1 && state.tabs.first.url.isEmpty) {
      if (state.activeIndex != 0) {
        state = TabsState(tabs: state.tabs, activeIndex: 0);
        unawaited(_saveToPrefs());
      }
      return;
    }
    final newTab = BrowserTab(url: url);
    final newTabs = [...state.tabs, newTab];
    state = TabsState(tabs: newTabs, activeIndex: newTabs.length - 1);
    unawaited(_saveToPrefs());
  }

  void closeTab(String tabId) {
    _snapshotService?.deleteSnapshot(tabId);
    
    if (state.tabs.length == 1) {
      _updateActiveTab(
        (tab) => tab.copyWith(url: '', title: 'New Tab'),
      );
      return;
    }

    final currentIndex = state.activeIndex;
    final tabToRemoveIndex = state.tabs.indexWhere((t) => t.id == tabId);
    if (tabToRemoveIndex == -1) return;

    final newTabs = [...state.tabs]..removeAt(tabToRemoveIndex);
    
    int newIndex = currentIndex;
    if (currentIndex >= newTabs.length) {
      newIndex = newTabs.length - 1;
    } else if (currentIndex > tabToRemoveIndex) {
      newIndex = currentIndex - 1;
    }

    state = TabsState(tabs: newTabs, activeIndex: newIndex);
    unawaited(_saveToPrefs());
  }

  void switchTab(int index) {
    if (index >= 0 && index < state.tabs.length) {
      state = TabsState(tabs: state.tabs, activeIndex: index);
      unawaited(_saveToPrefs());
    }
  }

  /// Reorder tabs (e.g. future drag-and-drop strip). Indices are pre-[ReorderableListView] rules.
  void reorderTab(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= state.tabs.length ||
        newIndex < 0 ||
        newIndex >= state.tabs.length) {
      return;
    }
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final tabs = [...state.tabs];
    final item = tabs.removeAt(oldIndex);
    tabs.insert(newIndex, item);

    var active = state.activeIndex;
    if (active == oldIndex) {
      active = newIndex;
    } else if (oldIndex < newIndex) {
      if (active > oldIndex && active <= newIndex) {
        active--;
      }
    } else {
      if (active >= newIndex && active < oldIndex) {
        active++;
      }
    }
    active = active.clamp(0, tabs.length - 1);
    state = TabsState(tabs: tabs, activeIndex: active);
    unawaited(_saveToPrefs());
  }

  void updateUrl(String newUrl) {
    if (state.tabs.isEmpty) return;
    if (state.tabs[state.activeIndex].url == newUrl) return;
    _updateActiveTab((tab) => tab.copyWith(url: newUrl), debounce: true);
  }

  void updateUrlForTab(String tabId, String newUrl) {
    _updateTabById(tabId, (tab) => tab.copyWith(url: newUrl), debounce: true);
  }

  void setWebError(String tabId, String? error) {
    _updateTabById(tabId, (tab) => tab.copyWith(webError: error ?? clearWebError));
  }

  void updateActiveTabCanGoBack(bool canGoBack) {
    if (state.tabs.isEmpty) return;
    if (state.tabs[state.activeIndex].canGoBack == canGoBack) return;
    _updateActiveTab((tab) => tab.copyWith(canGoBack: canGoBack));
  }
  
  void updateCanGoBack(String tabId, bool canGoBack) {
    final idx = state.tabs.indexWhere((t) => t.id == tabId);
    if (idx != -1) {
      final oldTab = state.tabs[idx];
      if (oldTab.canGoBack == canGoBack) return; // avoid rebuilds if no change
      
      final updatedTab = oldTab.copyWith(canGoBack: canGoBack);
      final newTabs = List<BrowserTab>.from(state.tabs)..[idx] = updatedTab;
      state = TabsState(tabs: newTabs, activeIndex: state.activeIndex);
    }
  }

  void updateTitle(String newTitle) {
    if (state.tabs.isEmpty) return;
    if (state.tabs[state.activeIndex].title == newTitle) return;
    _updateActiveTab((tab) => tab.copyWith(title: newTitle), debounce: true);
  }

  void updateTitleForTab(String tabId, String newTitle) {
    final index = state.tabs.indexWhere((tab) => tab.id == tabId);
    if (index == -1 || state.tabs[index].title == newTitle) return;
    _updateTabById(tabId, (tab) => tab.copyWith(title: newTitle), debounce: true);
  }

  // This resets the persistent tabs to a single blank tab
  void nuke() {
    if (_snapshotService != null) {
      for (final tab in state.tabs) {
        _snapshotService!.deleteSnapshot(tab.id);
      }
    }
    final newTabs = [BrowserTab()];
    state = TabsState(tabs: newTabs, activeIndex: 0);
    unawaited(_saveToPrefs());
  }

  void _updateActiveTab(BrowserTab Function(BrowserTab) updater, {bool debounce = false}) {
    final currentTabs = [...state.tabs];
    final activeTab = currentTabs[state.activeIndex];
    currentTabs[state.activeIndex] = updater(activeTab);
    state = TabsState(tabs: currentTabs, activeIndex: state.activeIndex);
    debounce ? _scheduleSave() : unawaited(_saveToPrefs());
  }

  void _updateTabById(
    String tabId,
    BrowserTab Function(BrowserTab) updater, {
    bool debounce = false,
  }) {
    final index = state.tabs.indexWhere((tab) => tab.id == tabId);
    if (index == -1) return;

    final currentTabs = [...state.tabs];
    currentTabs[index] = updater(currentTabs[index]);
    state = TabsState(tabs: currentTabs, activeIndex: state.activeIndex);
    debounce ? _scheduleSave() : unawaited(_saveToPrefs());
  }
}

// --- 3. THE PROVIDER ---
final tabsProvider = StateNotifierProvider<TabsNotifier, TabsState>((ref) {
  final prefsService = ref.watch(preferencesServiceProvider);
  final snapshotService = ref.watch(snapshotServiceProvider);
  return TabsNotifier(prefsService, snapshotService: snapshotService);
});

// --- 4. HELPER ---
final activeUrlProvider = Provider<String>((ref) {
  // safeActiveTab avoids a StateError crash during the transient empty-tabs
  // window (e.g. mid-nuke before the blank tab is added).
  return ref.watch(
    tabsProvider.select((s) => s.safeActiveTab?.url ?? ''),
  );
});
