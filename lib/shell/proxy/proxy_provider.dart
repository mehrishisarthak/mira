import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/services/proxy_service.dart';
import 'package:mira/shell/proxy/proxy_service_ios.dart';
import 'package:mira/shell/proxy/proxy_service_stub.dart';

/// In-app proxy: [IOSProxyService] (local Shelf gateway) on iOS; [StubProxyService]
/// on Android, desktop, and web (no in-process HTTP proxy; use OS / system proxy).
/// Use [ProxyService.runtimeBackend] or [ProxyRuntimeBackend] instead of scattering
/// `Platform.isIOS` checks when deciding whether URLs are rewritten.
final proxyServiceProvider = Provider<ProxyService>((ref) {
  if (!kIsWeb && Platform.isIOS) {
    return IOSProxyService();
  }
  return StubProxyService();
});
