import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/model/caching/caching.dart'; 
import 'package:mira/model/history_model.dart';
import '../constants/search_engines.dart';

// --- 0. PREFERENCES PROVIDER (The Missing Link) ---
// We define it here so other providers can watch it.
// It throws an error until you override it in main.dart.
final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  throw UnimplementedError('PreferencesService must be overridden in main.dart');
});

// --- 1. SEARCH ENGINE PROVIDER ---
class SearchEngineNotifier extends StateNotifier<String> {
  final PreferencesService _prefsService;

  SearchEngineNotifier(this._prefsService) : super(SearchEngines.google) {
    _loadFromPrefs();
  }

  void _loadFromPrefs() {
    final savedEngine = _prefsService.getSearchEngine();
    if (savedEngine != null && SearchEngines.urls.containsKey(savedEngine)) {
      state = savedEngine;
    }
  }

  Future<void> setEngine(String engineKey) async {
    if (SearchEngines.urls.containsKey(engineKey)) {
      state = engineKey; 
      await _prefsService.setSearchEngine(engineKey);
    }
  }
}

final searchEngineProvider = StateNotifierProvider<SearchEngineNotifier, String>((ref) {
  final prefsService = ref.watch(preferencesServiceProvider);
  return SearchEngineNotifier(prefsService);
});

// --- 2. HISTORY PROVIDER (New!) ---
class HistoryNotifier extends StateNotifier<List<HistoryItem>> {
  final PreferencesService _prefsService;

  HistoryNotifier(this._prefsService) : super([]) {
    _loadHistory();
  }

  void _loadHistory() {
    final jsonList = _prefsService.getHistory();
    state = jsonList.map((str) => HistoryItem.fromJson(str)).toList();
  }

  Future<void> addToHistory(String query) async {
    if (query.trim().isEmpty) return;
    final cleanQuery = query.trim();
    
    // Create copy of list to modify
    final currentList = [...state];

    // Remove duplicates so new one goes to top
    currentList.removeWhere((item) => item.text == cleanQuery);

    // Add new item at top
    currentList.insert(0, HistoryItem(text: cleanQuery, timestamp: DateTime.now()));

    // Keep only last 50 items
    if (currentList.length > 50) currentList.removeLast();

    // Update State & Save
    state = currentList;
    _saveToPrefs();
  }

  Future<void> removeFromHistory(HistoryItem item) async {
    final currentList = [...state];
    currentList.remove(item);
    state = currentList;
    _saveToPrefs();
  }

  Future<void> clearAllHistory() async {
    state = [];
    await _prefsService.clearHistory();
  }

  void _saveToPrefs() {
    final jsonList = state.map((item) => item.toJson()).toList();
    _prefsService.setHistory(jsonList);
  }
}

final historyProvider = StateNotifierProvider<HistoryNotifier, List<HistoryItem>>((ref) {
  final prefsService = ref.watch(preferencesServiceProvider);
  return HistoryNotifier(prefsService);
});

// --- 3. CURRENT URL PROVIDER ---
final currentUrlProvider = StateProvider<String>((ref) => '');

// --- 4. COMPUTED LOGIC ---
final formattedSearchUrlProvider = Provider.family<String, String>((ref, query) {
  final currentEngine = ref.watch(searchEngineProvider);
  final baseUrl = SearchEngines.getSearchUrl(currentEngine);
  
  return "$baseUrl${Uri.encodeComponent(query)}";
});