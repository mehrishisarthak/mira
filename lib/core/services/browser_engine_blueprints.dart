import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';

/// The standard event types that any [BrowserEngine] must broadcast.
enum BrowserPageEventType {
  loadStart,
  loadStop,
  progressChanged,
  titleChanged,
  error,
  downloadRequested,
  updateVisitedHistory,
}

/// A wrapper class for broadcasting web page events through the [BrowserEngine].
class BrowserPageEvent {
  final BrowserPageEventType type;
  final String? url;
  final String? title;
  final int? progress; // 0-100
  final String? errorDescription;
  final DownloadRequest? downloadRequest;
  final dynamic originalEvent;

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

class AdBlockRule {
  final String urlFilter;
  final bool isBlock; // true = BLOCK, false = IGNORE_PREVIOUS_RULES
  const AdBlockRule({required this.urlFilter, required this.isBlock});
}

class BrowserEngineConfig {
  final bool isDesktopMode;
  final bool isDarkMode;
  final bool isCameraBlocked;
  final bool isLocationBlocked;
  final List<AdBlockRule> adBlockRules;

  const BrowserEngineConfig({
    required this.isDesktopMode,
    required this.isDarkMode,
    required this.isCameraBlocked,
    required this.isLocationBlocked,
    this.adBlockRules = const [],
  });
}

/// The single contract between MIRA's core and any underlying web engine.
abstract class BrowserEngine {
  /// A stream of events broadcasting the engine's internal state and page activity.
  Stream<BrowserPageEvent> get pageEvents;

  // --- Lifecycle ---

  Future<void> init();
  Future<void> updateSettings(BrowserEngineConfig config);
  Future<void> dispose();
  Future<void> pauseRendering();
  Future<void> resumeRendering();

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
  Future<String> getPageHtml();
  Future<Uint8List?> takeSnapshot();

  // --- Identity & Privacy ---

  Future<void> setUserAgent(String ua);
  bool get isPrivate;
  int get lastProgress;

  // --- Storage ---

  Future<void> clearStorage();
  Future<void> clearCookies();

  /// Clears this engine's own native HTTP/resource cache. Unlike
  /// [clearStorage] and [clearCookies] — which operate on process-wide
  /// managers and so only need to be called once, on any single engine — the
  /// underlying cache API is per-webview-controller, so every instantiated
  /// engine needs its own explicit call for a full wipe (see "Nuke Data").
  Future<void> clearCache();

  // --- Zoom Capabilities ---

  Future<void> zoomIn();
  Future<void> zoomOut();
  Future<void> resetZoom();

  // --- Scripting ---

  Future<void> injectScript(String js, {bool atDocumentStart = false});

  /// Returns a Flutter widget that renders the web content.
  Widget buildWidget({required String tabId, String? initialUrl});
}


