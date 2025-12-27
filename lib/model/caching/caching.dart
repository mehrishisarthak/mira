import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  static const _keySearchEngine = 'selected_search_engine';
  static const _keySearchHistory = 'search_history'; // New Key

  // --- Search Engine ---
  String? getSearchEngine() {
    return _prefs.getString(_keySearchEngine);
  }

  Future<void> setSearchEngine(String engineKey) async {
    await _prefs.setString(_keySearchEngine, engineKey);
  }

  // --- Search History ---
  // Returns the list of stored history items (as JSON strings)
  List<String> getHistory() {
    return _prefs.getStringList(_keySearchHistory) ?? [];
  }

  // Saves the list of history items
  Future<void> setHistory(List<String> historyJsonList) async {
    await _prefs.setStringList(_keySearchHistory, historyJsonList);
  }
  
  // Clears the history completely (for the Fire Button or manual clear)
  Future<void> clearHistory() async {
    await _prefs.remove(_keySearchHistory);
  }
}