import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/model/caching/caching.dart'; // Imports the service AND the provider above
import '../constants/search_engines.dart';

// --- 1. SEARCH ENGINE PROVIDER (The Preference) ---
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

// The Provider: Watches the preferencesServiceProvider we defined in caching.dart
final searchEngineProvider = StateNotifierProvider<SearchEngineNotifier, String>((ref) {
  final prefsService = ref.watch(preferencesServiceProvider);
  return SearchEngineNotifier(prefsService);
});


// --- 2. CURRENT URL PROVIDER (The Input) ---
final currentUrlProvider = StateProvider<String>((ref) => '');


// --- 3. COMPUTED LOGIC ---
final formattedSearchUrlProvider = Provider.family<String, String>((ref, query) {
  final currentEngine = ref.watch(searchEngineProvider);
  final baseUrl = SearchEngines.getSearchUrl(currentEngine);
  
  return "$baseUrl${Uri.encodeComponent(query)}";
});