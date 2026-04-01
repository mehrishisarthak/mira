import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mira/core/services/browser_service.dart';
import 'package:mira/core/entities/security_entity.dart';

class AndroidBrowserService implements BrowserService {
  @override
  Future<void> applyProxy(SecurityState securityState) async {
    if (kIsWeb || !Platform.isAndroid) return;

    final proxyController = ProxyController.instance();
    final isSupported = await WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE);
    
    if (isSupported) {
      if (securityState.isProxyEnabled && securityState.proxyUrl.isNotEmpty) {
        await proxyController.setProxyOverride(
          settings: ProxySettings(
            proxyRules: [
              ProxyRule(url: securityState.proxyUrl)
            ],
            bypassRules: ["*.local"],
          ),
        );
      } else {
        await proxyController.clearProxyOverride();
      }
    }
  }

  @override
  Future<void> onTabClosed(String tabId) async {
    // Android specific cleanup if needed
  }
}

