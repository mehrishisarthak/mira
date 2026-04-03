import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:mira/core/entities/tab_entity.dart';
import 'package:mira/core/services/preferences_service.dart';

// --- 1. THE STATE CLASS ---
class TabsState {
  final List<BrowserTab> tabs;
  final int activeIndex;

  TabsState({required this.tabs, required this.activeIndex});

  BrowserTab get activeTab => tabs[activeIndex];
}

// --- 2. THE NOTIFIER ---
class TabsNotifier extends StateNotifier<TabsState> {
  final PreferencesService _prefsService;

  TabsNotifier(this._prefsService) : super(TabsState(tabs: [BrowserTab()], activeIndex: 0)) {
    _loadTabs();
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
        state = TabsState(tabs: loadedTabs, activeIndex: safeIndex);
      } catch (e, stack) {
        debugPrint('[MIRA] TabNotifier corrupted data: $e\n$stack');
        state = TabsState(
          tabs: [BrowserTab(id: const Uuid().v4())],
          activeIndex: 0,
        );
      }
    }
  }

  void _saveToPrefs() {
    final jsonList = state.tabs.map((tab) => tab.toJson()).toList();
    _prefsService.saveTabs(jsonList, state.activeIndex);
  }

  // --- ACTIONS ---

  void addTab({String url = ''}) {
    final newTab = BrowserTab(url: url);
    final newTabs = [...state.tabs, newTab];
    state = TabsState(tabs: newTabs, activeIndex: newTabs.length - 1);
    _saveToPrefs();
  }

  void closeTab(String tabId) {
    if (state.tabs.length == 1) {
      updateUrl(''); 
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
    _saveToPrefs();
  }

  void switchTab(int index) {
    if (index >= 0 && index < state.tabs.length) {
      state = TabsState(tabs: state.tabs, activeIndex: index);
      _saveToPrefs();
    }
  }

  void updateUrl(String newUrl) {
    _updateActiveTab((tab) => tab.copyWith(url: newUrl, title: newUrl));
  }

  void updateUrlForTab(String tabId, String newUrl) {
    _updateTabById(
      tabId,
      (tab) => tab.copyWith(url: newUrl, title: newUrl),
    );
  }
  
  void updateTitle(String newTitle) {
     _updateActiveTab((tab) => tab.copyWith(title: newTitle));
  }

  void updateTitleForTab(String tabId, String newTitle) {
    _updateTabById(
      tabId,
      (tab) => tab.copyWith(title: newTitle),
    );
  }

  // This resets the persistent tabs to a single blank tab
  void nuke() {
    final newTabs = [BrowserTab()];
    state = TabsState(tabs: newTabs, activeIndex: 0);
    _saveToPrefs();
  }

  void _updateActiveTab(BrowserTab Function(BrowserTab) updater) {
    final currentTabs = [...state.tabs];
    final activeTab = currentTabs[state.activeIndex];
    currentTabs[state.activeIndex] = updater(activeTab);
    state = TabsState(tabs: currentTabs, activeIndex: state.activeIndex);
    _saveToPrefs();
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
    _saveToPrefs();
  }
}

// --- 3. THE PROVIDER ---
final tabsProvider = StateNotifierProvider<TabsNotifier, TabsState>((ref) {
  final prefsService = ref.read(preferencesServiceProvider);
  return TabsNotifier(prefsService);
});

// --- 4. HELPER ---
final activeUrlProvider = Provider<String>((ref) {
  final tabsState = ref.watch(tabsProvider);
  return tabsState.activeTab.url;
});
