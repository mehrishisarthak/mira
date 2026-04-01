import 'package:mira/core/services/browser_service.dart';
import 'package:mira/core/entities/security_entity.dart';
import 'package:mira/core/notifiers/security_notifier.dart';

class StubBrowserService implements BrowserService {
  @override
  Future<void> applyProxy(SecurityState securityState) async {}

  @override
  Future<void> onTabClosed(String tabId) async {}
}

