import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/core/entities/tab_entity.dart';

/// Private / ghost tabs: **empty until** the user opens a private session from the menu
/// or a shortcut. Nothing is shown in the desktop tab strip until then.
class GhostTabsNotifier extends StateNotifier<TabsState> {
  GhostTabsNotifier() : super(TabsState(tabs: [], activeIndex: 0));

  void addTab({String url = ''}) {
    final newTab = BrowserTab(url: url, title: url.isEmpty ? 'New Tab' : 'Ghost Tab');
    final newTabs = [...state.tabs, newTab];
    state = TabsState(tabs: newTabs, activeIndex: newTabs.length - 1);
  }

  void closeTab(String id) {
    if (state.tabs.isEmpty) return;
    if (state.tabs.length <= 1) {
      state = TabsState(tabs: [], activeIndex: 0);
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
    if (state.tabs.isEmpty) return;
    if (index >= 0 && index < state.tabs.length) {
      state = TabsState(tabs: state.tabs, activeIndex: index);
    }
  }

  void reorderTab(int oldIndex, int newIndex) {
    if (state.tabs.isEmpty) return;
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
  }

  void updateUrl(String url) {
    if (state.tabs.isEmpty) return;
    if (state.tabs[state.activeIndex].url == url) return;
    _updateActiveTab((tab) => tab.copyWith(url: url));
  }

  void updateUrlForTab(String tabId, String url) {
    final index = state.tabs.indexWhere((tab) => tab.id == tabId);
    if (index == -1 || state.tabs[index].url == url) return;
    _updateTabById(
      tabId,
      (tab) => tab.copyWith(url: url),
    );
  }

  void updateTitle(String title) {
    if (state.tabs.isEmpty) return;
    if (state.tabs[state.activeIndex].title == title) return;
    _updateActiveTab((tab) => tab.copyWith(title: title));
  }

  void updateTitleForTab(String tabId, String title) {
    final index = state.tabs.indexWhere((tab) => tab.id == tabId);
    if (index == -1 || state.tabs[index].title == title) return;
    _updateTabById(
      tabId,
      (tab) => tab.copyWith(title: title),
    );
  }

  void _updateActiveTab(BrowserTab Function(BrowserTab) updater) {
    if (state.tabs.isEmpty) return;
    final currentTabs = [...state.tabs];
    final i = state.activeIndex.clamp(0, currentTabs.length - 1);
    final activeTab = currentTabs[i];
    currentTabs[i] = updater(activeTab);
    state = TabsState(tabs: currentTabs, activeIndex: i);
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
    state = TabsState(tabs: [], activeIndex: 0);
  }
}

final ghostTabsProvider = StateNotifierProvider<GhostTabsNotifier, TabsState>((ref) {
  return GhostTabsNotifier();
});

final isGhostModeProvider = StateProvider<bool>((ref) => false);

final currentTabListProvider = Provider<List<BrowserTab>>((ref) {
  final isGhost = ref.watch(isGhostModeProvider);
  return isGhost
      ? ref.watch(ghostTabsProvider.select((s) => s.tabs))
      : ref.watch(tabsProvider.select((s) => s.tabs));
});

final currentActiveTabProvider = Provider<BrowserTab>((ref) {
  final isGhost = ref.watch(isGhostModeProvider);
  if (!isGhost) {
    return ref.watch(tabsProvider.select((s) => s.activeTab));
  }
  final ghost = ref.watch(ghostTabsProvider.select((s) => s.safeActiveTab));
  if (ghost != null) return ghost;
  return ref.watch(tabsProvider.select((s) => s.activeTab));
});

/// Active-session tab count only. `.select`s the length so watchers rebuild on
/// add/remove/switch — not on every url/title tick of a tab (O-07).
final tabCountProvider = Provider<int>((ref) {
  final isGhost = ref.watch(isGhostModeProvider);
  return isGhost
      ? ref.watch(ghostTabsProvider.select((s) => s.tabs.length))
      : ref.watch(tabsProvider.select((s) => s.tabs.length));
});
