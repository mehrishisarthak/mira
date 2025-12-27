import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  static const _keySearchEngine = 'selected_search_engine';
  static const _keySearchHistory = 'search_history'; 
  static const _keySavedTabs = 'saved_tabs';     // NEW KEY
  static const _keyActiveTabIndex = 'active_tab_index'; // NEW KEY

  // --- Search Engine ---
  String? getSearchEngine() => _prefs.getString(_keySearchEngine);
  Future<void> setSearchEngine(String engineKey) async => await _prefs.setString(_keySearchEngine, engineKey);

  // --- History ---
  List<String> getHistory() => _prefs.getStringList(_keySearchHistory) ?? [];
  Future<void> setHistory(List<String> history) async => await _prefs.setStringList(_keySearchHistory, history);
  Future<void> clearHistory() async => await _prefs.remove(_keySearchHistory);

  // --- TABS PERSISTENCE (NEW) ---
  
  List<String> getSavedTabs() {
    return _prefs.getStringList(_keySavedTabs) ?? [];
  }

  int getActiveTabIndex() {
    return _prefs.getInt(_keyActiveTabIndex) ?? 0;
  }

  Future<void> saveTabs(List<String> tabsJson, int activeIndex) async {
    await _prefs.setStringList(_keySavedTabs, tabsJson);
    await _prefs.setInt(_keyActiveTabIndex, activeIndex);
  }
}