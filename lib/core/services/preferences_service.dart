import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  // --- KEYS ---
  static const _keySearchEngine = 'selected_search_engine';
  static const _keySavedTabs = 'saved_tabs';     
  static const _keyActiveTabIndex = 'active_tab_index';
  
  // Security Keys
  static const _keyLocation = 'mode_location';
  static const _keyCamera = 'mode_camera';
  static const _keyDesktop = 'mode_desktop';
  static const _keyAdBlock = 'adblock_enabled';
  // Theme Keys
  static const _keyTheme = 'app_theme_style'; // For Color Accent
  static const _keyThemeMode = 'app_theme_mode'; // For Light/Dark/System

  // Onboarding Key (NEW)
  static const _keyFirstRun = 'is_first_run';

  // AdBlock OTA Keys
  static const _keyAdBlockOtaLastCheck = 'adblock_ota_last_check'; // epoch millis
  static const _keyAdBlockOtaSha = 'adblock_ota_sha'; // last applied sha256

  // --- SEARCH ENGINE ---
  String? getSearchEngine() => _prefs.getString(_keySearchEngine);
  Future<void> setSearchEngine(String engineKey) async => await _prefs.setString(_keySearchEngine, engineKey);

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

  // Location Block (Default: true -> Privacy first)
  bool getLocationBlock() => _prefs.getBool(_keyLocation) ?? true;
  Future<void> setLocationBlock(bool value) async => await _prefs.setBool(_keyLocation, value);

  // Camera/Mic Block (Default: true -> Privacy first)
  bool getCameraBlock() => _prefs.getBool(_keyCamera) ?? true;
  Future<void> setCameraBlock(bool value) async => await _prefs.setBool(_keyCamera, value);

  // Desktop Mode (Default: false)
  bool getDesktopMode() => _prefs.getBool(_keyDesktop) ?? false;
  Future<void> setDesktopMode(bool value) async => await _prefs.setBool(_keyDesktop, value);

  // Ad Block (Default: true — privacy first)
  bool getAdBlockEnabled() => _prefs.getBool(_keyAdBlock) ?? true;
  Future<void> setAdBlockEnabled(bool value) async => await _prefs.setBool(_keyAdBlock, value);

  // --- THEME (COLORS) ---
  // Returns the index of the selected theme (0 = Green, 1 = Yellow, etc.)
  int getThemeStyle() => _prefs.getInt(_keyTheme) ?? 0; 
  Future<void> setThemeStyle(int index) async => await _prefs.setInt(_keyTheme, index);

  // --- THEME MODE (LIGHT/DARK/SYSTEM) ---
  // Default to 0 (ThemeMode.system in Flutter is usually index 0)
  int getThemeMode() => _prefs.getInt(_keyThemeMode) ?? 0;
  Future<void> setThemeMode(int index) async => await _prefs.setInt(_keyThemeMode, index);

  // --- ONBOARDING (NEW) ---
  // Returns true if key doesn't exist yet (First time user)
  bool getFirstRun() => _prefs.getBool(_keyFirstRun) ?? true;
  Future<void> setFirstRun(bool value) async => await _prefs.setBool(_keyFirstRun, value);

  // --- ADBLOCK OTA ---
  int getAdBlockOtaLastCheck() => _prefs.getInt(_keyAdBlockOtaLastCheck) ?? 0;
  Future<void> setAdBlockOtaLastCheck(int epochMillis) async => await _prefs.setInt(_keyAdBlockOtaLastCheck, epochMillis);

  String? getAdBlockOtaSha() => _prefs.getString(_keyAdBlockOtaSha);
  Future<void> setAdBlockOtaSha(String sha) async => await _prefs.setString(_keyAdBlockOtaSha, sha);
}

/// Second desktop engine for private windows: keep theme/settings on disk but never
/// clobber the main window’s saved tab restore.
class EphemeralTabPersistencePreferences extends PreferencesService {
  EphemeralTabPersistencePreferences(super._prefs);

  @override
  List<String> getSavedTabs() => [];

  @override
  int getActiveTabIndex() => 0;

  @override
  Future<void> saveTabs(List<String> tabsJson, int activeIndex) async {}
}

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  assert(
    false,
    '\n[MIRA ERROR] preferencesServiceProvider not overridden.\n'
    'Add overrideWithValue(PreferencesService(prefs)) in ProviderScope.\n',
  );
  throw StateError(
    'preferencesServiceProvider accessed without ProviderScope override.',
  );
});
