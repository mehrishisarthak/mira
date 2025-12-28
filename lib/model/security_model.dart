import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/model/caching/caching.dart'; // Ensure this points to your PreferencesService
import 'package:mira/model/search_engine.dart';

class SecurityState {
  final bool isIncognito;
  final bool isLocationBlocked;
  final bool isCameraBlocked;
  final bool isDesktopMode;
  final bool isAdBlockEnabled;

  SecurityState({
    required this.isIncognito,
    required this.isLocationBlocked,
    required this.isCameraBlocked,
    required this.isDesktopMode,
    required this.isAdBlockEnabled,
  });

  SecurityState copyWith({
    bool? isIncognito,
    bool? isLocationBlocked,
    bool? isCameraBlocked,
    bool? isDesktopMode,
    bool? isAdBlockEnabled,
  }) {
    return SecurityState(
      isIncognito: isIncognito ?? this.isIncognito,
      isLocationBlocked: isLocationBlocked ?? this.isLocationBlocked,
      isCameraBlocked: isCameraBlocked ?? this.isCameraBlocked,
      isDesktopMode: isDesktopMode ?? this.isDesktopMode,
      isAdBlockEnabled: isAdBlockEnabled ?? this.isAdBlockEnabled,
    );
  }
}

class SecurityNotifier extends StateNotifier<SecurityState> {
  final PreferencesService _prefs;

  SecurityNotifier(this._prefs) : super(SecurityState(
    isIncognito: false,
    isLocationBlocked: true,
    isCameraBlocked: true,
    isDesktopMode: false,
    isAdBlockEnabled: true, // Default to Safe
  )) {
    _loadSettings();
  }

  void _loadSettings() {
    state = SecurityState(
      isIncognito: _prefs.getIncognito(),
      isLocationBlocked: _prefs.getLocationBlock(),
      isCameraBlocked: _prefs.getCameraBlock(),
      isDesktopMode: _prefs.getDesktopMode(),
      isAdBlockEnabled: _prefs.getAdBlock(), // Load Shield State
    );
  }

  void toggleIncognito(bool value) {
    state = state.copyWith(isIncognito: value);
    _prefs.setIncognito(value);
  }

  void toggleLocation(bool value) {
    state = state.copyWith(isLocationBlocked: value);
    _prefs.setLocationBlock(value);
  }

  void toggleCamera(bool value) {
    state = state.copyWith(isCameraBlocked: value);
    _prefs.setCameraBlock(value);
  }

  void toggleDesktop(bool value) {
    state = state.copyWith(isDesktopMode: value);
    _prefs.setDesktopMode(value);
  }
  
  // NEW: Toggle The Shield
  void toggleAdBlock(bool value) {
    state = state.copyWith(isAdBlockEnabled: value);
    _prefs.setAdBlock(value);
  }
}

// THE PROVIDER
final securityProvider = StateNotifierProvider<SecurityNotifier, SecurityState>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return SecurityNotifier(prefs);
});