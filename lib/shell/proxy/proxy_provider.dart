import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/services/proxy_service.dart';
import 'package:mira/shell/proxy/proxy_service_ios.dart';
import 'package:mira/shell/proxy/proxy_service_stub.dart';

/// Provider for the platform-appropriate ProxyService.
final proxyServiceProvider = Provider<ProxyService>((ref) {
  if (!kIsWeb && Platform.isIOS) {
    return IOSProxyService();
  }
  return StubProxyService();
});
