import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  // --- KEYS ---
  static const _keySearchEngine = 'selected_search_engine';
  static const _keySearchHistory = 'search_history'; 
  static const _keySavedTabs = 'saved_tabs';     
  static const _keyActiveTabIndex = 'active_tab_index';
  
  // Security Keys
  static const _keyIncognito = 'mode_incognito';
  static const _keyLocation = 'mode_location'; 
  static const _keyCamera = 'mode_camera';     
  static const _keyDesktop = 'mode_desktop';
  static const _keyAdBlock = 'mode_adblock'; 
  
  // Bookmarks Key (NEW)
  static const _keyBookmarks = 'saved_bookmarks';

  // --- SEARCH ENGINE ---
  String? getSearchEngine() => _prefs.getString(_keySearchEngine);
  Future<void> setSearchEngine(String engineKey) async => await _prefs.setString(_keySearchEngine, engineKey);

  // --- HISTORY ---
  List<String> getHistory() => _prefs.getStringList(_keySearchHistory) ?? [];
  Future<void> setHistory(List<String> history) async => await _prefs.setStringList(_keySearchHistory, history);
  Future<void> clearHistory() async => await _prefs.remove(_keySearchHistory);

  // --- BOOKMARKS (NEW) ---
  List<String> getBookmarks() => _prefs.getStringList(_keyBookmarks) ?? [];
  Future<void> setBookmarks(List<String> bookmarks) async => await _prefs.setStringList(_keyBookmarks, bookmarks);

  // --- TABS PERSISTENCE ---
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

  // --- SECURITY MODES ---

  // Incognito (Default: false -> We want logins to work by default)
  bool getIncognito() => _prefs.getBool(_keyIncognito) ?? false;
  Future<void> setIncognito(bool value) async => await _prefs.setBool(_keyIncognito, value);

  // Location Block (Default: true -> Privacy first)
  bool getLocationBlock() => _prefs.getBool(_keyLocation) ?? true;
  Future<void> setLocationBlock(bool value) async => await _prefs.setBool(_keyLocation, value);

  // Camera/Mic Block (Default: true -> Privacy first)
  bool getCameraBlock() => _prefs.getBool(_keyCamera) ?? true;
  Future<void> setCameraBlock(bool value) async => await _prefs.setBool(_keyCamera, value);

  // Desktop Mode (Default: false)
  bool getDesktopMode() => _prefs.getBool(_keyDesktop) ?? false;
  Future<void> setDesktopMode(bool value) async => await _prefs.setBool(_keyDesktop, value);

  // AdBlock / The Shield (Default: true -> MIRA protects you out of the box)
  bool getAdBlock() => _prefs.getBool(_keyAdBlock) ?? true;
  Future<void> setAdBlock(bool value) async => await _prefs.setBool(_keyAdBlock, value);
}