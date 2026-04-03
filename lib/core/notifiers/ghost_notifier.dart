import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/core/entities/tab_entity.dart';

class GhostTabsNotifier extends StateNotifier<TabsState> {
  GhostTabsNotifier() : super(TabsState(tabs: [BrowserTab(title: "Ghost Tab")], activeIndex: 0));

  void addTab({String url = ''}) {
    final newTab = BrowserTab(url: url);
    final newTabs = [...state.tabs, newTab];
    state = TabsState(tabs: newTabs, activeIndex: newTabs.length - 1);
  }

  void closeTab(String id) {
    if (state.tabs.length <= 1) {
      updateUrl(''); 
      return;
    }
    
    final currentIndex = state.activeIndex;
    final indexToRemove = state.tabs.indexWhere((t) => t.id == id);
    if (indexToRemove == -1) return;

    final newTabs = [...state.tabs]..removeAt(indexToRemove);

    int newIndex = currentIndex;
    if (currentIndex >= newTabs.length) {
      newIndex = newTabs.length - 1;
    } else if (currentIndex > indexToRemove) {
      newIndex = currentIndex - 1;
    }

    state = TabsState(tabs: newTabs, activeIndex: newIndex);
  }

  void switchTab(int index) {
    if (index >= 0 && index < state.tabs.length) {
      state = TabsState(tabs: state.tabs, activeIndex: index);
    }
  }

  void updateUrl(String url) {
    _updateActiveTab((tab) => tab.copyWith(url: url));
  }

  void updateUrlForTab(String tabId, String url) {
    _updateTabById(
      tabId,
      (tab) => tab.copyWith(url: url),
    );
  }
  
  void updateTitle(String title) {
    _updateActiveTab((tab) => tab.copyWith(title: title));
  }

  void updateTitleForTab(String tabId, String title) {
    _updateTabById(
      tabId,
      (tab) => tab.copyWith(title: title),
    );
  }

  void _updateActiveTab(BrowserTab Function(BrowserTab) updater) {
    final currentTabs = [...state.tabs];
    final activeTab = currentTabs[state.activeIndex];
    currentTabs[state.activeIndex] = updater(activeTab);
    state = TabsState(tabs: currentTabs, activeIndex: state.activeIndex);
  }

  void _updateTabById(
    String tabId,
    BrowserTab Function(BrowserTab) updater,
  ) {
    final index = state.tabs.indexWhere((tab) => tab.id == tabId);
    if (index == -1) return;

    final currentTabs = [...state.tabs];
    currentTabs[index] = updater(currentTabs[index]);
    state = TabsState(tabs: currentTabs, activeIndex: state.activeIndex);
  }

  void nuke() {
    final newTabs = [BrowserTab(title: "Ghost Tab")];
    state = TabsState(tabs: newTabs, activeIndex: 0);
  }
}

final ghostTabsProvider = StateNotifierProvider<GhostTabsNotifier, TabsState>((ref) {
  return GhostTabsNotifier();
});

final isGhostModeProvider = StateProvider<bool>((ref) => false);

final currentTabListProvider = Provider<List<BrowserTab>>((ref) {
  final isGhost = ref.watch(isGhostModeProvider);
  return isGhost ? ref.watch(ghostTabsProvider).tabs : ref.watch(tabsProvider).tabs;
});

final currentActiveTabProvider = Provider<BrowserTab>((ref) {
  final isGhost = ref.watch(isGhostModeProvider);
  return isGhost ? ref.watch(ghostTabsProvider).activeTab : ref.watch(tabsProvider).activeTab;
});
