import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Encrypted-at-rest persistence for normal-tab URLs/titles (O-04).
///
/// Normal `saved_tabs` used to live in plaintext SharedPreferences XML, which
/// contradicts the privacy brand. This stores the same JSON list in
/// flutter_secure_storage (Keystore/Keychain-backed). The active index is *not*
/// sensitive and stays in SharedPreferences (synchronous, no migration).
///
/// Design goal: never lose tabs. Every path falls back to the legacy plaintext
/// list, so a device with a broken/unavailable Keystore degrades to the old
/// behaviour instead of dropping the user's tabs.
class SecureTabStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _secureKey = 'saved_tabs_enc';
  static const String _legacyPlaintextKey = 'saved_tabs';

  /// Loads the tab JSON list, migrating any legacy plaintext list out of
  /// [prefs] (and wiping it) on first run with this build. Called once in
  /// `main()` before `runApp`, so the rest of the app keeps its synchronous
  /// tab API. The cost is one Keystore read, comfortably inside the splash
  /// buffer.
  static Future<List<String>> load(SharedPreferences prefs) async {
    try {
      final raw = await _storage.read(key: _secureKey);
      if (raw != null) {
        return (jsonDecode(raw) as List).cast<String>();
      }
      // First run on this build: migrate plaintext -> encrypted, then wipe the
      // plaintext copy so it no longer sits unencrypted on disk.
      final legacy = prefs.getStringList(_legacyPlaintextKey) ?? const [];
      if (legacy.isNotEmpty) {
        await _storage.write(key: _secureKey, value: jsonEncode(legacy));
        await prefs.remove(_legacyPlaintextKey);
      }
      return legacy;
    } catch (e) {
      // Keystore unavailable/corrupt — degrade to plaintext rather than lose
      // the user's tabs.
      debugPrint('MIRA: secure tab load failed, using plaintext fallback: $e');
      return prefs.getStringList(_legacyPlaintextKey) ?? const [];
    }
  }

  /// Persists the tab JSON list to encrypted storage. Failures are logged, not
  /// thrown — a save miss must never crash the browser.
  static Future<void> save(List<String> tabsJson) async {
    try {
      await _storage.write(key: _secureKey, value: jsonEncode(tabsJson));
    } catch (e) {
      debugPrint('MIRA: secure tab save failed: $e');
    }
  }
}
