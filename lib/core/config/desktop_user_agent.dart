import 'package:flutter/foundation.dart';

/// Cached desktop user-agent string fetched from the active BrowserEngine.
String? _cachedEngineUa;

/// Sets the cached user-agent string. Called by the bootstrap logic or 
/// the concrete engine implementation at startup.
void setCachedDesktopUserAgent(String? ua) {
  _cachedEngineUa = ua;
}

/// Returns the UA to pass to [BrowserEngine.setUserAgent].
String? desktopModeUserAgent({
  required bool isDesktop,
  required bool desktopModeOn,
}) {
  if (isDesktop) return null;
  if (!desktopModeOn) return null;
  return _cachedEngineUa;
}
