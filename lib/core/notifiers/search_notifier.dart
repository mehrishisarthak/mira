import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/entities/search_entity.dart';
import 'package:mira/core/services/preferences_service.dart';
import 'package:mira/constants/search_engines.dart';

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

final formattedSearchUrlProvider = Provider.family<String, String>((ref, query) {
  final currentEngine = ref.watch(searchEngineProvider);
  final baseUrl = SearchEngines.getSearchUrl(currentEngine);
  
  return "$baseUrl${Uri.encodeComponent(query)}";
});

class SearchNotifier extends StateNotifier<Search> {
  SearchNotifier(super.state);

  void updateUrl(String urlProvided) {
    state = state.copyWith(url: urlProvided);
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, Search>((ref) {
  return SearchNotifier(Search(url: ''));
});
