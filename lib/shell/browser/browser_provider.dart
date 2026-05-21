import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/services/browser_service.dart';
import 'package:mira/shell/browser/browser_service_stub.dart';

/// DEPRECATED: Legacy service provider.
/// In the new architecture, proxy and engine settings are handled directly
/// by the [BrowserEngine] abstraction via [BrowserEngineConfig]. 
/// This provider is kept temporarily as a stub to prevent import errors in periphery files.
final browserServiceProvider = Provider<BrowserService>((ref) {
  return StubBrowserService();
});