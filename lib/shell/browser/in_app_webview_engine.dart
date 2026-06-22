import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mira/core/services/browser_engine_blueprints.dart'; // BrowserEngine, BrowserEngineConfig, AdBlockRule
import 'package:mira/core/config/desktop_user_agent.dart';

/// The concrete implementation of [BrowserEngine] using the flutter_inappwebview plugin.
class InAppWebViewEngine implements BrowserEngine {
  /// Fetches the default engine user agent. Static to support bootstrap fetching.
  static Future<String?> fetchDefaultUserAgent() async {
    if (kIsWeb) return null;
    return await InAppWebViewController.getDefaultUserAgent();
  }

  final StreamController<BrowserPageEvent> _eventController =
      StreamController<BrowserPageEvent>.broadcast();

  InAppWebViewController? _controller;
  final bool _isPrivate;

  // Mutable permission flags — updated live via updateSettings()
  bool _isCameraBlocked = true;
  bool _isLocationBlocked = true;
  List<ContentBlocker> _contentBlockers;

  String? _pendingUrl;
  Map<String, String>? _pendingHeaders;

  int _lastProgress = 100;
  String? _currentUrl;

  InAppWebViewEngine({
    bool isPrivate = false,
    List<AdBlockRule> adBlockRules = const [],
  })  : _isPrivate = isPrivate,
        _contentBlockers = _toContentBlockers(adBlockRules);

  // The rule set is a single shared, immutable instance (the AdBlockService
  // cache), so rebuilding ~2.5k ContentBlocker objects on every settings change
  // (theme / permission toggles) is wasted work. Memoize on the rules identity;
  // this only rebuilds on a genuine adblock on/off transition.
  static List<AdBlockRule>? _memoRules;
  static List<ContentBlocker>? _memoBlockers;

  static List<ContentBlocker> _toContentBlockers(List<AdBlockRule> rules) {
    if (identical(rules, _memoRules) && _memoBlockers != null) {
      return _memoBlockers!;
    }
    final built = _buildContentBlockers(rules);
    _memoRules = rules;
    _memoBlockers = built;
    return built;
  }

  static List<ContentBlocker> _buildContentBlockers(List<AdBlockRule> rules) {
    // ContentBlocker (WebKit-style) is only supported on Android/iOS/macOS.
    // On Windows/Linux the plugin's ContentBlockerActionType native value is
    // null, and accessing e.g. ContentBlockerActionType.BLOCK throws
    // 'Null is not a subtype of String'. Skip content blockers there.
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      return const [];
    }
    // IGNORE_PREVIOUS_RULES is a WebKit-only action: its native value is null
    // on Android, so merely accessing the enum there throws the same
    // 'Null is not a subtype of String'. Only emit ignore rules on iOS/macOS.
    final supportsIgnore = Platform.isIOS || Platform.isMacOS;

    // WebKit requires BLOCK rules to appear at a lower index than any
    // IGNORE_PREVIOUS_RULES rule for the same domain. Re-partition here so
    // this invariant holds even if the source JSON was regenerated out of order.
    final blocks = <ContentBlocker>[];
    final ignores = <ContentBlocker>[];
    for (final r in rules) {
      if (!r.isBlock && !supportsIgnore) continue;
      final cb = ContentBlocker(
        trigger: ContentBlockerTrigger(
          urlFilter: r.urlFilter,
          loadType: [ContentBlockerTriggerLoadType.THIRD_PARTY],
        ),
        action: ContentBlockerAction(
          type: r.isBlock
              ? ContentBlockerActionType.BLOCK
              : ContentBlockerActionType.IGNORE_PREVIOUS_RULES,
        ),
      );
      (r.isBlock ? blocks : ignores).add(cb);
    }
    return [...blocks, ...ignores];
  }

  @override
  int get lastProgress => _lastProgress;

  /// Internal method to link the native [InAppWebViewController] once initialized by the view.
  void setController(InAppWebViewController controller) {
    _controller = controller;
    if (_pendingUrl != null) {
      loadUrl(_pendingUrl!, headers: _pendingHeaders);
      _pendingUrl = null;
      _pendingHeaders = null;
    }
  }

  @override
  Stream<BrowserPageEvent> get pageEvents => _eventController.stream;

  @override
  bool get isPrivate => _isPrivate;

  // --- Lifecycle ---

  @override
  Future<void> init() async {}

  @override
  Future<void> updateSettings(BrowserEngineConfig config) async {
    _isCameraBlocked = config.isCameraBlocked;
    _isLocationBlocked = config.isLocationBlocked;
    _contentBlockers = _toContentBlockers(config.adBlockRules);

    final settings = InAppWebViewSettings(
      forceDark: config.isDarkMode ? ForceDark.ON : ForceDark.OFF,
      algorithmicDarkeningAllowed: config.isDarkMode,
      userAgent: desktopModeUserAgent(
        isDesktop: !kIsWeb &&
            (Platform.isWindows || Platform.isMacOS || Platform.isLinux),
        desktopModeOn: config.isDesktopMode,
      ),
      preferredContentMode: config.isDesktopMode
          ? UserPreferredContentMode.DESKTOP
          : UserPreferredContentMode.MOBILE,
      geolocationEnabled: !config.isLocationBlocked,
      contentBlockers: _contentBlockers,
    );

    await _controller?.setSettings(settings: settings);
  }

  @override
  Future<void> dispose() async {
    await _eventController.close();
    _controller = null;
    _pendingUrl = null;
    _pendingHeaders = null;
  }

  @override
  Future<void> hibernate() async {
    await _controller?.pause();
  }

  @override
  Future<void> wake() async {
    await _controller?.resume();
  }

  // --- Navigation ---

  @override
  Future<void> loadUrl(String url, {Map<String, String>? headers}) async {
    if (_controller == null) {
      _pendingUrl = url;
      _pendingHeaders = headers;
      return;
    }
    await _controller?.loadUrl(
      urlRequest: URLRequest(
        url: WebUri(url),
        headers: headers,
      ),
    );
  }

  @override
  Future<void> reload() async {
    await _controller?.reload();
  }

  @override
  Future<void> goBack() async {
    await _controller?.goBack();
  }

  @override
  Future<void> goForward() async {
    await _controller?.goForward();
  }

  @override
  Future<void> stopLoading() async {
    await _controller?.stopLoading();
  }

  @override
  Future<bool> canGoBack() async {
    return (await _controller?.canGoBack()) ?? false;
  }

  @override
  Future<bool> canGoForward() async {
    return (await _controller?.canGoForward()) ?? false;
  }

  // --- Introspection ---

  @override
  Future<String> currentUrl() async {
    return (await _controller?.getUrl())?.toString() ?? "";
  }

  @override
  Future<String> currentTitle() async {
    return (await _controller?.getTitle()) ?? "";
  }

  @override
  Future<String> getPageHtml() async {
    final result = await _controller?.evaluateJavascript(
      source: "document.documentElement.outerHTML",
    );
    return result?.toString() ?? "";
  }

  @override
  Future<Uint8List?> takeSnapshot() async {
    return await _controller?.takeScreenshot();
  }

  // --- Identity & Privacy ---

  @override
  Future<void> setUserAgent(String ua) async {
    await _controller?.setSettings(
      settings: InAppWebViewSettings(userAgent: ua),
    );
  }

  // --- Storage ---

  @override
  Future<void> clearStorage() async {
    await WebStorageManager.instance().deleteAllData();
  }

  @override
  Future<void> clearCookies() async {
    await CookieManager.instance().deleteAllCookies();
  }

  // --- Zoom Capabilities ---

  @override
  Future<void> zoomIn() async {
    await _controller?.zoomIn();
  }

  @override
  Future<void> zoomOut() async {
    await _controller?.zoomOut();
  }

  @override
  Future<void> resetZoom() async {
    await _controller?.zoomBy(zoomFactor: 1.0);
  }

  // --- Scripting ---

  @override
  Future<void> injectScript(String js, {bool atDocumentStart = false}) async {
    if (atDocumentStart) {
      await _controller?.addUserScript(
        userScript: UserScript(
          source: js,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      );
    } else {
      await _controller?.evaluateJavascript(source: js);
    }
  }

  @override
  Widget buildWidget({required String tabId, String? initialUrl}) {
    // Prevent double-load: if the pending URL matches what initialUrlRequest will load,
    // let initialUrlRequest handle it and discard the pending loadUrl call.
    if (initialUrl != null && initialUrl.isNotEmpty && _pendingUrl == initialUrl) {
      _pendingUrl = null;
      _pendingHeaders = null;
    }
    return InAppWebView(
      key: ObjectKey(tabId),
      initialUrlRequest: (initialUrl != null && initialUrl.isNotEmpty)
          ? URLRequest(url: WebUri(initialUrl))
          : null,
      initialSettings: InAppWebViewSettings(
        incognito: _isPrivate,
        transparentBackground: true,
        useShouldOverrideUrlLoading: true,
        useOnDownloadStart: true,
        geolocationEnabled: !_isLocationBlocked,
        contentBlockers: _contentBlockers,
      ),
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        return NavigationActionPolicy.ALLOW;
      },
      onWebViewCreated: (controller) {
        setController(controller);
      },
      onPermissionRequest: (controller, request) async {
        final sensorRequested = request.resources.where((r) =>
            r == PermissionResourceType.CAMERA ||
            r == PermissionResourceType.MICROPHONE).toList();
        if (sensorRequested.isEmpty) return null;
        return PermissionResponse(
          resources: sensorRequested,
          action: _isCameraBlocked
              ? PermissionResponseAction.DENY
              : PermissionResponseAction.GRANT,
        );
      },
      onGeolocationPermissionsShowPrompt: (controller, origin) async {
        return GeolocationPermissionShowPromptResponse(
          origin: origin,
          allow: !_isLocationBlocked,
          retain: false,
        );
      },
      onLoadStart: (controller, url) {
        handleLoadStart(url);
      },
      onLoadStop: (controller, url) {
        handleLoadStop(url);
      },
      onProgressChanged: (controller, progress) {
        handleProgressChanged(progress);
      },
      onTitleChanged: (controller, title) {
        handleTitleChanged(title);
      },
      onReceivedError: (controller, request, error) {
        handleReceivedError(request, error);
      },
      onDownloadStartRequest: (controller, request) {
        handleDownloadRequest(request);
      },
    );
  }

  // --- Native Callback Mappings ---

  void handleLoadStart(WebUri? url) {
    _lastProgress = 0;
    _currentUrl = url?.toString();
    _eventController.add(BrowserPageEvent(
      type: BrowserPageEventType.loadStart,
      url: url?.toString(),
    ));
  }

  void handleLoadStop(WebUri? url) {
    _lastProgress = 100;
    _currentUrl = url?.toString();
    _eventController.add(BrowserPageEvent(
      type: BrowserPageEventType.loadStop,
      url: url?.toString(),
    ));
  }

  void handleProgressChanged(int progress) {
    _lastProgress = progress;
    _eventController.add(BrowserPageEvent(
      type: BrowserPageEventType.progressChanged,
      progress: progress,
    ));
  }

  void handleTitleChanged(String? title) {
    // Stamp the current url so the history-title refiner keys off the page the
    // title actually belongs to, not whatever tab is active when this lands.
    _eventController.add(BrowserPageEvent(
      type: BrowserPageEventType.titleChanged,
      title: title,
      url: _currentUrl,
    ));
  }

  void handleReceivedError(WebResourceRequest request, WebResourceError error) {
    // Default ambiguous (null) frame to non-main: a blocked-ad/subframe error
    // should not trigger the full-screen error page, especially with ad-block on.
    if (request.isForMainFrame ?? false) {
      _eventController.add(BrowserPageEvent(
        type: BrowserPageEventType.error,
        errorDescription: error.description,
        url: request.url.toString(),
      ));
    }
  }

  Future<void> handleDownloadRequest(DownloadStartRequest request) async {
    final cookies = await CookieManager.instance().getCookies(url: request.url);
    final cookieString = cookies.map((c) => '${c.name}=${c.value}').join('; ');

    final downloadReq = DownloadRequest(
      url: request.url.toString(),
      filename: request.suggestedFilename,
      userAgent: request.userAgent,
      cookies: cookieString,
    );

    _eventController.add(BrowserPageEvent(
      type: BrowserPageEventType.downloadRequested,
      downloadRequest: downloadReq,
    ));
  }
}
