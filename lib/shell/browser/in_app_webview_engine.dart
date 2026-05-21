import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mira/core/services/browser_engine_blueprints.dart';
import 'package:mira/core/config/desktop_user_agent.dart';
import 'package:mira/core/services/ad_block_service.dart';

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
  ContentFilter? _contentFilter;
  ProxyConfig? _proxyConfig;
  final bool _isPrivate;

  InAppWebViewEngine({bool isPrivate = false}) : _isPrivate = isPrivate;

  /// Internal method to link the native [InAppWebViewController] once initialized by the view.
  void setController(InAppWebViewController controller) {
    _controller = controller;
  }

  @override
  Stream<BrowserPageEvent> get pageEvents => _eventController.stream;

  @override
  bool get isPrivate => _isPrivate;

  // --- Lifecycle ---

  @override
  Future<void> init() async {
    // Basic initialization if any global plugin state is needed.
  }

  @override
  Future<void> updateSettings(BrowserEngineConfig config) async {
    final forceDarkSetting = config.isDarkMode ? ForceDark.ON : ForceDark.OFF;
    
    final settings = InAppWebViewSettings(
      forceDark: forceDarkSetting,
      algorithmicDarkeningAllowed: config.isDarkMode,
      userAgent: desktopModeUserAgent(
        isDesktop: !kIsWeb &&
            (Platform.isWindows || Platform.isMacOS || Platform.isLinux),
        desktopModeOn: config.isDesktopMode,
      ),
      preferredContentMode: config.isDesktopMode
          ? UserPreferredContentMode.DESKTOP
          : UserPreferredContentMode.MOBILE,
    );

    await _controller?.setSettings(settings: settings);
  }

  @override
  Future<void> dispose() async {
    await _eventController.close();
    _controller = null;
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

  // --- Middleware & Extension Hooks ---

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
  Future<void> registerContentFilter(ContentFilter filter) async {
    _contentFilter = filter;
  }

  @override
  Future<bool> registerProxyConfig(ProxyConfig config) async {
    _proxyConfig = config;
    return true;
  }

  @override
  Widget buildWidget({required String tabId}) {
    return InAppWebView(
      key: ObjectKey(tabId),
      initialSettings: InAppWebViewSettings(
        incognito: _isPrivate,
        transparentBackground: true,
        useShouldOverrideUrlLoading: true,
        useOnDownloadStart: true,
        contentBlockers: AdBlockService.adBlockRegexes.map((regex) {
          return ContentBlocker(
            trigger: ContentBlockerTrigger(
              urlFilter: regex,
              resourceType: [
                ContentBlockerTriggerResourceType.SCRIPT,
                ContentBlockerTriggerResourceType.IMAGE,
                ContentBlockerTriggerResourceType.MEDIA,
                ContentBlockerTriggerResourceType.FONT,
              ],
            ),
            action: ContentBlockerAction(
              type: ContentBlockerActionType.BLOCK,
            ),
          );
        }).toList(),
      ),
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: AdBlockService.fullShieldScript,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      ]),
      shouldInterceptRequest: (controller, request) async {
        final host = request.url.host;
        if (AdBlockService.blockedDomains.any((domain) => 
            host == domain || host.endsWith('.$domain'))) {
          return WebResourceResponse(
            contentType: 'text/plain',
            data: Uint8List(0),
          );
        }
        return null;
      },
      onWebViewCreated: (controller) {
        setController(controller);
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
    _eventController.add(BrowserPageEvent(
      type: BrowserPageEventType.loadStart,
      url: url?.toString(),
    ));
  }

  void handleLoadStop(WebUri? url) {
    _eventController.add(BrowserPageEvent(
      type: BrowserPageEventType.loadStop,
      url: url?.toString(),
    ));
  }

  void handleProgressChanged(int progress) {
    _eventController.add(BrowserPageEvent(
      type: BrowserPageEventType.progressChanged,
      progress: progress,
    ));
  }

  void handleTitleChanged(String? title) {
    _eventController.add(BrowserPageEvent(
      type: BrowserPageEventType.titleChanged,
      title: title,
    ));
  }

  void handleReceivedError(WebResourceRequest request, WebResourceError error) {
    if (request.isForMainFrame ?? true) {
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