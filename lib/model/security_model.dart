import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/model/caching/caching.dart';
import 'package:mira/model/search_engine.dart';

class SecurityState {
  final bool isIncognito;
  final bool isLocationBlocked;
  final bool isCameraBlocked;
  final bool isDesktopMode;

  SecurityState({
    required this.isIncognito,
    required this.isLocationBlocked,
    required this.isCameraBlocked,
    required this.isDesktopMode,
  });

  SecurityState copyWith({
    bool? isIncognito,
    bool? isLocationBlocked,
    bool? isCameraBlocked,
    bool? isDesktopMode,
  }) {
    return SecurityState(
      isIncognito: isIncognito ?? this.isIncognito,
      isLocationBlocked: isLocationBlocked ?? this.isLocationBlocked,
      isCameraBlocked: isCameraBlocked ?? this.isCameraBlocked,
      isDesktopMode: isDesktopMode ?? this.isDesktopMode,
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
  )) {
    _loadSettings();
  }

  void _loadSettings() {
    state = SecurityState(
      isIncognito: _prefs.getIncognito(),
      isLocationBlocked: _prefs.getLocationBlock(),
      isCameraBlocked: _prefs.getCameraBlock(),
      isDesktopMode: _prefs.getDesktopMode(),
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
}

// THE PROVIDER
final securityProvider = StateNotifierProvider<SecurityNotifier, SecurityState>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return SecurityNotifier(prefs);
});