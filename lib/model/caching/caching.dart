import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// This is the provider your SearchEngineNotifier watches.
// We override it in main.dart with the real instance.
final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  throw UnimplementedError('PreferencesService not initialized');
});

class PreferencesService {
  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  static const _keySearchEngine = 'selected_search_engine';

  String? getSearchEngine() {
    return _prefs.getString(_keySearchEngine);
  }

  Future<void> setSearchEngine(String engineKey) async {
    await _prefs.setString(_keySearchEngine, engineKey);
  }
}