import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/model/tab_model.dart'; // Import BrowserTab and TabsState from here

// --- 1. GHOST TABS NOTIFIER (RAM ONLY) ---
// Now extends TabsState just like the main provider to prevent Index Crashes
class GhostTabsNotifier extends StateNotifier<TabsState> {
  
  // Start with 1 Ghost Tab at Index 0
  GhostTabsNotifier() : super(TabsState(tabs: [BrowserTab(title: "Ghost Tab")], activeIndex: 0));

  // Add Tab
  void addTab({String url = ''}) {
    final newTab = BrowserTab(url: url);
    final newTabs = [...state.tabs, newTab];
    // Auto-switch to new tab
    state = TabsState(tabs: newTabs, activeIndex: newTabs.length - 1);
  }

  // Close Tab (With Index Safety Logic)
  void closeTab(String id) {
    if (state.tabs.length <= 1) {
      updateUrl(''); // Just clear if last one
      return;
    }
    
    final currentIndex = state.activeIndex;
    final indexToRemove = state.tabs.indexWhere((t) => t.id == id);
    if (indexToRemove == -1) return;

    final newTabs = [...state.tabs]..removeAt(indexToRemove);

    // CRITICAL FIX: Recalculate Index so we don't crash
    int newIndex = currentIndex;
    if (currentIndex >= newTabs.length) {
      newIndex = newTabs.length - 1;
    } else if (currentIndex > indexToRemove) {
      newIndex = currentIndex - 1;
    }

    state = TabsState(tabs: newTabs, activeIndex: newIndex);
  }

  // Switch Tab
  void switchTab(int index) {
    if (index >= 0 && index < state.tabs.length) {
      state = TabsState(tabs: state.tabs, activeIndex: index);
    }
  }

  // Update URL (Operates on Active Tab)
  void updateUrl(String url) {
    _updateActiveTab((tab) => tab.copyWith(url: url, title: url));
  }
  
  // Update Title (Operates on Active Tab)
  void updateTitle(String title) {
    _updateActiveTab((tab) => tab.copyWith(title: title));
  }

  // Helper
  void _updateActiveTab(BrowserTab Function(BrowserTab) updater) {
    final currentTabs = [...state.tabs];
    final activeTab = currentTabs[state.activeIndex];
    currentTabs[state.activeIndex] = updater(activeTab);
    state = TabsState(tabs: currentTabs, activeIndex: state.activeIndex);
  }

  // Nuke (Reset)
  void nuke() {
    final newTabs = [BrowserTab(title: "Ghost Tab")];
    state = TabsState(tabs: newTabs, activeIndex: 0);
  }

  void add({required String url}) {}
}

// --- 2. THE PROVIDERS ---

// Renamed to 'ghostTabsProvider' to match 'tabsProvider' convention
final ghostTabsProvider = StateNotifierProvider<GhostTabsNotifier, TabsState>((ref) {
  return GhostTabsNotifier();
});

// --- 3. THE MODE SWITCHER ---
final isGhostModeProvider = StateProvider<bool>((ref) => false);

// --- 4. THE "SMART" PROVIDERS ---

// Returns the Current Tabs List
final currentTabListProvider = Provider<List<BrowserTab>>((ref) {
  final isGhost = ref.watch(isGhostModeProvider);
  // Both providers now return TabsState, so we access .tabs on both
  return isGhost ? ref.watch(ghostTabsProvider).tabs : ref.watch(tabsProvider).tabs;
});

// Returns the Active Tab
final currentActiveTabProvider = Provider<BrowserTab>((ref) {
  final isGhost = ref.watch(isGhostModeProvider);
  // Both providers now maintain their own activeIndex internally
  return isGhost ? ref.watch(ghostTabsProvider).activeTab : ref.watch(tabsProvider).activeTab;
});