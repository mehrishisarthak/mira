import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/widgets.dart'; // FIX: Required for 'Widget' return type

/// The standard event types that any [BrowserEngine] must broadcast.
enum BrowserPageEventType {
  loadStart,
  loadStop,
  progressChanged,
  titleChanged,
  error,
  downloadRequested,
}

/// A wrapper class for broadcasting web page events through the [BrowserEngine].
class BrowserPageEvent {
  final BrowserPageEventType type;
  final String? url;
  final String? title;
  final int? progress; // 0-100
  final String? errorDescription;
  final DownloadRequest? downloadRequest;
  final dynamic originalEvent; // For passing through engine-specific raw data if needed

  const BrowserPageEvent({
    required this.type,
    this.url,
    this.title,
    this.progress,
    this.errorDescription,
    this.downloadRequest,
    this.originalEvent,
  });
}

/// A structured data object representing a web-initiated download request.
/// Extracted by the engine and passed to the app's [DownloadManager].
class DownloadRequest {
  final String url;
  final String? filename;
  final Map<String, String>? headers;
  final String? cookies;
  final String? userAgent;

  const DownloadRequest({
    required this.url,
    this.filename,
    this.headers,
    this.cookies,
    this.userAgent,
  });
}

/// The contract for middleware that filters network traffic or content.
abstract class ContentFilter {
  /// Enables/disables the filter globally.
  bool get enabled;
  
  /// Updates the filter rules dynamically.
  Future<void> updateRules(List<String> newRules);
}

/// The contract for engine-level proxy configuration.
abstract class ProxyConfig {
  final String url;
  final bool allowInsecureCertificates;

  const ProxyConfig({
    required this.url,
    this.allowInsecureCertificates = false,
  });
}

class BrowserEngineConfig {
  final bool isDesktopMode;
  final bool isAdBlockEnabled;
  final bool isDarkMode;

  const BrowserEngineConfig({
    required this.isDesktopMode,
    required this.isAdBlockEnabled,
    required this.isDarkMode,
  });
}

/// The single contract between MIRA's core and any underlying web engine.
abstract class BrowserEngine {
  /// A stream of events broadcasting the engine's internal state and page activity.
  Stream<BrowserPageEvent> get pageEvents;

  // --- Lifecycle ---
  
  /// Initialize the engine instance with optional configuration.
  Future<void> init();

  /// Updates the engine's settings dynamically.
  Future<void> updateSettings(BrowserEngineConfig config);

  /// Dispose of the engine and its native resources.
  Future<void> dispose();

  /// Put the engine in a low-power hibernation state (e.g., kill native process).
  Future<void> hibernate();

  /// Resume the engine from a hibernated state.
  Future<void> wake();

  // --- Navigation ---

  Future<void> loadUrl(String url, {Map<String, String>? headers});
  
  Future<void> reload();
  
  Future<void> goBack();
  
  Future<void> goForward();
  
  Future<void> stopLoading();

  Future<bool> canGoBack();
  
  Future<bool> canGoForward();

  // --- Introspection ---

  Future<String> currentUrl();
  
  Future<String> currentTitle();

  /// Captures the current visible state for hibernation thumbnails.
  Future<Uint8List?> takeSnapshot();

  // --- Identity & Privacy ---

  Future<void> setUserAgent(String ua);

  /// True if the engine was initialized in an ephemeral/incognito context.
  bool get isPrivate;

  /// Returns the last known loading progress (0-100) of the engine.
  int get lastProgress;

  // --- Storage ---

  Future<void> clearStorage();
  
  Future<void> clearCookies();

  // --- Zoom Capabilities ---

  Future<void> zoomIn();
  
  Future<void> zoomOut();
  
  Future<void> resetZoom();

  // --- Middleware & Extension Hooks ---

  /// Injects a block of JavaScript into the page.
  Future<void> injectScript(String js, {bool atDocumentStart = false});

  /// Registers a dynamic content filter (e.g., Ad-blocker).
  Future<void> registerContentFilter(ContentFilter filter);

  /// Configures the engine-level proxy.
  /// Returns true if a reload is required to apply the config.
  Future<bool> registerProxyConfig(ProxyConfig config);

  /// Returns a Flutter widget that renders the web content.
  /// This allows the UI to remain agnostic of the underlying native implementation.
  Widget buildWidget({required String tabId, String? initialUrl});
}