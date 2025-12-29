import 'dart:convert'; // Required for JSON
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/model/search_engine.dart';
import 'package:uuid/uuid.dart';
import 'package:mira/model/caching/caching.dart'; 

// --- 1. THE MODEL ---
class BrowserTab {
  final String id;
  final String url;
  final String title;
  final bool isLoading;
  
  BrowserTab({
    String? id,
    this.url = '',
    this.title = 'New Tab',
    this.isLoading = false,
  }) : id = id ?? const Uuid().v4(); //giving  tabs an id

  BrowserTab copyWith({
    String? id,
    String? url,
    String? title,
    bool? isLoading,
  }) {
    return BrowserTab(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'title': title,
    };
  }

  factory BrowserTab.fromMap(Map<String, dynamic> map) {
    return BrowserTab(
      id: map['id'],
      url: map['url'] ?? '',
      title: map['title'] ?? 'New Tab',
    );
  }

  String toJson() => json.encode(toMap());
  factory BrowserTab.fromJson(String source) => BrowserTab.fromMap(json.decode(source));
}

// --- 2. THE STATE CLASS ---
class TabsState {
  final List<BrowserTab> tabs;
  final int activeIndex;

  TabsState({required this.tabs, required this.activeIndex});

  BrowserTab get activeTab => tabs[activeIndex];
}

// --- 3. THE NOTIFIER ---
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
        final loadedTabs = savedJsonList.map((str) => BrowserTab.fromJson(str)).toList();
        int safeIndex = savedIndex;
        if (safeIndex < 0 || safeIndex >= loadedTabs.length) {
          safeIndex = 0;
        }
        state = TabsState(tabs: loadedTabs, activeIndex: safeIndex);
      } catch (e) {
        // Corrupted data, start fresh
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
  
  void updateTitle(String newTitle) {
     _updateActiveTab((tab) => tab.copyWith(title: newTitle));
  }

  // --- THE MISSING NUKE METHOD ---
  // This resets the persistent tabs to a single blank tab
  void nuke() {
    state = TabsState(tabs: [BrowserTab()], activeIndex: 0);
    _saveToPrefs(); // Save the "empty" state to disk immediately
  }

  void _updateActiveTab(BrowserTab Function(BrowserTab) updater) {
    final currentTabs = [...state.tabs];
    final activeTab = currentTabs[state.activeIndex];
    currentTabs[state.activeIndex] = updater(activeTab);
    state = TabsState(tabs: currentTabs, activeIndex: state.activeIndex);
    _saveToPrefs();
  }
}

// --- 4. THE PROVIDER ---
final tabsProvider = StateNotifierProvider<TabsNotifier, TabsState>((ref) {
  final prefsService = ref.watch(preferencesServiceProvider);
  return TabsNotifier(prefsService);
});

// --- 5. HELPER ---
final activeUrlProvider = Provider<String>((ref) {
  final tabsState = ref.watch(tabsProvider);
  return tabsState.activeTab.url;
});