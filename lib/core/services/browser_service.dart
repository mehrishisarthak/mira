import 'package:mira/core/entities/security_entity.dart';

abstract class BrowserService {
  /// Applies platform-specific proxy configuration (e.g. WebViewFeature.PROXY_OVERRIDE on Android)
  Future<void> applyProxy(SecurityState securityState);
  
  /// Performs any platform-specific cleanup on tab close
  Future<void> onTabClosed(String tabId);
}

