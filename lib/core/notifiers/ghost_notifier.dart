import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qyx/core/entities/tab_entity.dart';
import 'package:qyx/core/notifiers/tab_notifier.dart'; // To get NormalizedTabsState

class GhostTabsNotifier extends StateNotifier<NormalizedTabsState> {
  GhostTabsNotifier() : super(const NormalizedTabsState(tabOrder: [], tabs: {}, activeIndex: 0));

  void addTab({String url = ''}) {
    final newTab = BrowserTab(url: url);
    final newMap = Map<String, BrowserTab>.from(state.tabs);
    newMap[newTab.id] = newTab;
    final newOrder = List<String>.from(state.tabOrder)..add(newTab.id);

    state = NormalizedTabsState(tabOrder: newOrder, tabs: newMap, activeIndex: newOrder.length - 1);
  }

  void closeTab(String tabId) {
    if (state.tabOrder.length == 1) {
      _updateActiveTab((tab) => tab.copyWith(url: '', title: 'New Private Tab'));
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
  }

  void switchTab(int index) {
    if (index >= 0 && index < state.tabOrder.length) {
      state = state.copyWith(activeIndex: index);
    }
  }

  /// Switches to a tab by its stable id rather than its position in
  /// [NormalizedTabsState.tabOrder]. See [TabsNotifier.switchTabById] for
  /// the rationale — avoids acting on a stale captured index.
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
  }

  void updateUrl(String newUrl) {
    if (state.tabOrder.isEmpty) return;
    final activeTab = state.tabs[state.tabOrder[state.activeIndex]]!;
    if (activeTab.url == newUrl) return;
    _updateActiveTab((tab) => tab.copyWith(url: newUrl));
  }

  void updateUrlForTab(String tabId, String newUrl) {
    _updateTabById(tabId, (tab) => tab.copyWith(url: newUrl));
  }

  void setWebError(String tabId, String? error) {
    _updateTabById(tabId, (tab) => tab.copyWith(webError: error));
  }

  void updateActiveTabCanGoBack(bool canGoBack) {
    if (state.tabOrder.isEmpty) return;
    final activeTab = state.tabs[state.tabOrder[state.activeIndex]]!;
    if (activeTab.canGoBack == canGoBack) return;
    _updateActiveTab((tab) => tab.copyWith(canGoBack: canGoBack));
  }

  /// Both nav flags in one write — see TabsNotifier.updateActiveTabNavState.
  void updateActiveTabNavState(bool canGoBack, bool canGoForward) {
    if (state.tabOrder.isEmpty) return;
    final activeTab = state.tabs[state.tabOrder[state.activeIndex]]!;
    if (activeTab.canGoBack == canGoBack &&
        activeTab.canGoForward == canGoForward) {
      return;
    }
    _updateActiveTab(
      (tab) => tab.copyWith(canGoBack: canGoBack, canGoForward: canGoForward),
    );
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
    _updateActiveTab((tab) => tab.copyWith(title: newTitle));
  }

  void updateTitleForTab(String tabId, String newTitle) {
    final targetTab = state.tabs[tabId];
    if (targetTab == null || targetTab.title == newTitle) return;
    _updateTabById(tabId, (tab) => tab.copyWith(title: newTitle));
  }

  void nuke() {
    state = const NormalizedTabsState(tabOrder: [], tabs: {}, activeIndex: 0);
  }

  void _updateActiveTab(BrowserTab Function(BrowserTab) updater) {
    if (state.tabOrder.isEmpty) return;
    final activeId = state.tabOrder[state.activeIndex];
    _updateTabById(activeId, updater);
  }

  void _updateTabById(String tabId, BrowserTab Function(BrowserTab) updater) {
    if (!state.tabs.containsKey(tabId)) return;
    final newMap = Map<String, BrowserTab>.from(state.tabs);
    newMap[tabId] = updater(newMap[tabId]!);
    state = state.copyWith(tabs: newMap);
  }
}

final ghostTabsProvider = StateNotifierProvider<GhostTabsNotifier, NormalizedTabsState>((ref) {
  return GhostTabsNotifier();
});

final isGhostModeProvider = StateProvider<bool>((ref) => false);


