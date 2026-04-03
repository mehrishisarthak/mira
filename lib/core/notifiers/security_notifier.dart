import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/entities/security_entity.dart';
import 'package:mira/core/services/preferences_service.dart';

class SecurityNotifier extends StateNotifier<SecurityState> {
  final PreferencesService _prefs;

  SecurityNotifier(this._prefs) : super(SecurityState(
    isIncognito: false,
    isLocationBlocked: true,
    isCameraBlocked: true,
    isDesktopMode: false,
    isAdBlockEnabled: true,
    isProxyEnabled: false,
    proxyUrl: "",
  )) {
    _loadSettings();
  }

  void _loadSettings() {
    state = SecurityState(
      isIncognito: _prefs.getIncognito(),
      isLocationBlocked: _prefs.getLocationBlock(),
      isCameraBlocked: _prefs.getCameraBlock(),
      isDesktopMode: _prefs.getDesktopMode(),
      isAdBlockEnabled: _prefs.getAdBlock(), 
      isProxyEnabled: _prefs.getProxyEnabled(),
      proxyUrl: _prefs.getProxyUrl(),
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
  
  void toggleAdBlock(bool value) {
    state = state.copyWith(isAdBlockEnabled: value);
    _prefs.setAdBlock(value);
  }

  void toggleProxy(bool value) {
    state = state.copyWith(isProxyEnabled: value);
    _prefs.setProxyEnabled(value);
  }

  void updateProxyUrl(String value) {
    state = state.copyWith(proxyUrl: value);
    _prefs.setProxyUrl(value);
  }
}

final securityProvider = StateNotifierProvider<SecurityNotifier, SecurityState>((ref) {
  final prefs = ref.read(preferencesServiceProvider);
  return SecurityNotifier(prefs);
});
