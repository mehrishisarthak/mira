import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:qyx/core/entities/tab_entity.dart';
import 'package:qyx/core/services/preferences_service.dart';
import 'package:qyx/core/services/snapshot_service.dart';

@immutable
class NormalizedTabsState {
  final List<String> tabOrder;
  final Map<String, BrowserTab> tabs;
  final int activeIndex;

  const NormalizedTabsState({
    required this.tabOrder,
    required this.tabs,
    required this.activeIndex,
  });

  BrowserTab get activeTab {
    if (tabOrder.isEmpty) {
      throw StateError('NormalizedTabsState has no tabs');
    }
    final i = activeIndex.clamp(0, tabOrder.length - 1);
    return tabs[tabOrder[i]]!;
  }

  BrowserTab? get safeActiveTab {
    if (tabOrder.isEmpty) return null;
    final i = activeIndex.clamp(0, tabOrder.length - 1);
    return tabs[tabOrder[i]];
  }

  NormalizedTabsState copyWith({
    List<String>? tabOrder,
    Map<String, BrowserTab>? tabs,
    int? activeIndex,
  }) {
    return NormalizedTabsState(
      tabOrder: tabOrder ?? this.tabOrder,
      tabs: tabs ?? this.tabs,
      activeIndex: activeIndex ?? this.activeIndex,
    );
  }
}

class TabsNotifier extends StateNotifier<NormalizedTabsState> {
  final PreferencesService _prefsService;
  final SnapshotService? _snapshotService;
  Timer? _saveDebounce;

  TabsNotifier(this._prefsService, {SnapshotService? snapshotService})
      : _snapshotService = snapshotService,
        super(const NormalizedTabsState(tabOrder: [], tabs: {}, activeIndex: 0)) {
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
        final loadedTabs = savedJsonList.map((str) => BrowserTab.fromJson(str)).toList();
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

        if (isDesktop && loadedTabs.isNotEmpty && loadedTabs[safeIndex].url.isNotEmpty) {
          nextTabs = [BrowserTab(), ...loadedTabs];
          nextIndex = 0;
          didPrependFreshDial = true;
        }

        final Map<String, BrowserTab> normalizedMap = {};
        final List<String> normalizedOrder = [];
        for (final t in nextTabs) {
          normalizedMap[t.id] = t;
          normalizedOrder.add(t.id);
        }

        state = NormalizedTabsState(tabOrder: normalizedOrder, tabs: normalizedMap, activeIndex: nextIndex);

        if (didPrependFreshDial) {
          unawaited(_saveToPrefs());
        }
      } catch (e, stack) {
        debugPrint(' TabNotifier corrupted data: $e\n$stack');
        final seed = BrowserTab(id: const Uuid().v4());
        state = NormalizedTabsState(
          tabOrder: [seed.id],
          tabs: {seed.id: seed},
          activeIndex: 0,
        );
      }
    } else {
      final seed = BrowserTab(id: const Uuid().v4());
      state = NormalizedTabsState(
        tabOrder: [seed.id],
        tabs: {seed.id: seed},
        activeIndex: 0,
      );
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final jsonList = state.tabOrder.map((id) => state.tabs[id]!.toJson()).toList();
      await _prefsService.saveTabs(jsonList, state.activeIndex);
    } catch (e) {
      debugPrint(' TabNotifier: failed to persist tab state: $e');
    }
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () => unawaited(_saveToPrefs()));
  }

  Future<void> flush() async {
    if (!(_saveDebounce?.isActive ?? false)) return;
    _saveDebounce?.cancel();
    await _saveToPrefs();
  }

  void addTab({String url = ''}) {
    if (url.isEmpty && state.tabOrder.length == 1 && state.tabs[state.tabOrder.first]!.url.isEmpty) {
      if (state.activeIndex != 0) {
        state = state.copyWith(activeIndex: 0);
        unawaited(_saveToPrefs());
      }
      return;
    }

    final newTab = BrowserTab(url: url);
    final newMap = Map<String, BrowserTab>.from(state.tabs);
    newMap[newTab.id] = newTab;
    final newOrder = List<String>.from(state.tabOrder)..add(newTab.id);

    state = NormalizedTabsState(tabOrder: newOrder, tabs: newMap, activeIndex: newOrder.length - 1);
    unawaited(_saveToPrefs());
  }

  void closeTab(String tabId) {
    _snapshotService?.deleteSnapshot(tabId);

    if (state.tabOrder.length == 1) {
      _updateActiveTab((tab) => tab.copyWith(url: '', title: 'New Tab'));
      return;
    }

    final currentIndex = state.activeIndex;
    final tabToRemoveIndex = state.tabOrder.indexOf(tabId);
    if (tabToRemoveIndex == -1) return;

    final newOrder = List<String>.from(state.tabOrder)..removeAt(tabToRemoveIndex);
    final newMap = Map<String, BrowserTab>.from(state.tabs)..remove(tabId);

    int newIndex = currentIndex;
    if (currentIndex >= newOrder.length) {
      newIndex = newOrder.length - 1;
    } else if (currentIndex > tabToRemoveIndex) {
      newIndex = currentIndex - 1;
    }

    state = NormalizedTabsState(tabOrder: newOrder, tabs: newMap, activeIndex: newIndex);
    unawaited(_saveToPrefs());
  }

  void switchTab(int index) {
    if (index >= 0 && index < state.tabOrder.length) {
      state = state.copyWith(activeIndex: index);
      unawaited(_saveToPrefs());
    }
  }

  /// Switches to a tab by its stable id rather than its position in
  /// [NormalizedTabsState.tabOrder]. Prefer this over [switchTab] wherever
  /// the caller resolves the target from a closure captured at build time
  /// (e.g. a ListView item's tap handler) — the list can reorder between
  /// build and tap, and a captured index would then point at the wrong tab.
  void switchTabById(String tabId) {
    final index = state.tabOrder.indexOf(tabId);
    if (index != -1) {
      switchTab(index);
    }
  }

  void reorderTab(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.tabOrder.length || newIndex < 0 || newIndex >= state.tabOrder.length) {
      return;
    }
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final newOrder = List<String>.from(state.tabOrder);
    final item = newOrder.removeAt(oldIndex);
    newOrder.insert(newIndex, item);

    var active = state.activeIndex;
    if (active == oldIndex) {
      active = newIndex;
    } else if (oldIndex < newIndex) {
      if (active > oldIndex && active <= newIndex) active--;
    } else {
      if (active >= newIndex && active < oldIndex) active++;
    }
    active = active.clamp(0, newOrder.length - 1);

    state = state.copyWith(tabOrder: newOrder, activeIndex: active);
    unawaited(_saveToPrefs());
  }

  void updateUrl(String newUrl) {
    if (state.tabOrder.isEmpty) return;
    final activeTab = state.tabs[state.tabOrder[state.activeIndex]]!;
    if (activeTab.url == newUrl) return;
    _updateActiveTab((tab) => tab.copyWith(url: newUrl), debounce: true);
  }

  void updateUrlForTab(String tabId, String newUrl) {
    _updateTabById(tabId, (tab) => tab.copyWith(url: newUrl), debounce: true);
  }

  void setWebError(String tabId, String? error) {
    _updateTabById(tabId, (tab) => tab.copyWith(webError: error ?? clearWebError));
  }

  void updateActiveTabCanGoBack(bool canGoBack) {
    if (state.tabOrder.isEmpty) return;
    final activeTab = state.tabs[state.tabOrder[state.activeIndex]]!;
    if (activeTab.canGoBack == canGoBack) return;
    _updateActiveTab((tab) => tab.copyWith(canGoBack: canGoBack));
  }
  
  void updateCanGoBack(String tabId, bool canGoBack) {
    if (!state.tabs.containsKey(tabId)) return;
    final oldTab = state.tabs[tabId]!;
    if (oldTab.canGoBack == canGoBack) return;
    _updateTabById(tabId, (tab) => tab.copyWith(canGoBack: canGoBack));
  }

  void updateTitle(String newTitle) {
    if (state.tabOrder.isEmpty) return;
    final activeTab = state.tabs[state.tabOrder[state.activeIndex]]!;
    if (activeTab.title == newTitle) return;
    _updateActiveTab((tab) => tab.copyWith(title: newTitle), debounce: true);
  }

  void updateTitleForTab(String tabId, String newTitle) {
    final targetTab = state.tabs[tabId];
    if (targetTab == null || targetTab.title == newTitle) return;
    _updateTabById(tabId, (tab) => tab.copyWith(title: newTitle), debounce: true);
  }

  void nuke() {
    if (_snapshotService != null) {
      for (final tabId in state.tabOrder) {
        _snapshotService.deleteSnapshot(tabId);
      }
    }
    final seed = BrowserTab();
    state = NormalizedTabsState(tabOrder: [seed.id], tabs: {seed.id: seed}, activeIndex: 0);
    unawaited(_saveToPrefs());
  }

  void _updateActiveTab(BrowserTab Function(BrowserTab) updater, {bool debounce = false}) {
    if (state.tabOrder.isEmpty) return;
    final activeId = state.tabOrder[state.activeIndex];
    _updateTabById(activeId, updater, debounce: debounce);
  }

  void _updateTabById(String tabId, BrowserTab Function(BrowserTab) updater, {bool debounce = false}) {
    if (!state.tabs.containsKey(tabId)) return;
    final newMap = Map<String, BrowserTab>.from(state.tabs);
    newMap[tabId] = updater(newMap[tabId]!);
    state = state.copyWith(tabs: newMap);
    debounce ? _scheduleSave() : unawaited(_saveToPrefs());
  }
}

final tabsProvider = StateNotifierProvider<TabsNotifier, NormalizedTabsState>((ref) {
  final prefsService = ref.watch(preferencesServiceProvider);
  final snapshotService = ref.watch(snapshotServiceProvider);
  return TabsNotifier(prefsService, snapshotService: snapshotService);
});

final activeUrlProvider = Provider<String>((ref) {
  return ref.watch(tabsProvider.select((s) => s.safeActiveTab?.url ?? ''));
});

final specificTabProvider = Provider.family<BrowserTab?, String>((ref, id) {
  return ref.watch(tabsProvider.select((s) => s.tabs[id]));
});

final currentActiveTabProvider = Provider<BrowserTab?>((ref) {
  return ref.watch(tabsProvider.select((s) => s.safeActiveTab));
});

final tabCountProvider = Provider<int>((ref) {
  return ref.watch(tabsProvider.select((s) => s.tabOrder.length));
});


