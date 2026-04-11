import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Cached desktop user-agent string fetched from the real WebView engine.
///
/// On desktop, [desktopModeUserAgent] returns `null` so the engine's native
/// (already-desktop) UA is used unchanged.  On mobile with "Desktop Mode" on,
/// we return the string fetched at startup so it always matches the real engine
/// version instead of a hardcoded Chrome/12x that goes stale.
String? _cachedEngineUa;

/// Call once during app bootstrap (after `WidgetsFlutterBinding.ensureInitialized`).
/// this way we can easily use the real engine's UA string for desktop mode on mobile
/// UA Strings is used by websites to determine which version of the site to serve (desktop or mobile).
Future<void> initDesktopUserAgent() async {
  if (kIsWeb) return;
  try {
    _cachedEngineUa = await InAppWebViewController.getDefaultUserAgent();
  } catch (e) {
    debugPrint('MIRA: getDefaultUserAgent failed ($e), will use engine default');
  }
}

/// Returns the UA to pass to [InAppWebViewSettings.userAgent].
///
/// * Desktop platforms → `null` (native engine UA is already desktop-class).
/// * Mobile with desktop mode ON → the real engine UA fetched at startup.
/// * Mobile with desktop mode OFF → `null` (engine default, typically mobile).
String? desktopModeUserAgent({
  required bool isDesktop,
  required bool desktopModeOn,
}) {
  if (isDesktop) return null;
  if (!desktopModeOn) return null;
  return _cachedEngineUa;
}
