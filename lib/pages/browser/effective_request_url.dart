import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mira/core/entities/security_entity.dart';
import 'package:mira/core/notifiers/proxy_notifier.dart';
import 'package:mira/core/services/proxy_service.dart';
import 'package:mira/shell/proxy/proxy_provider.dart';

String effectiveBrowserUrl(
    String originalUrl, WidgetRef ref, SecurityState security) {
  if (originalUrl.isEmpty) return originalUrl;

  final gateway = ref.read(proxyServiceProvider);
  final isGatewayRunning = ref.read(proxyGatewayStatusProvider);
  if (!kIsWeb &&
      gateway.runtimeBackend == ProxyRuntimeBackend.iosLocalGateway &&
      security.isProxyEnabled &&
      isGatewayRunning) {
    if (gateway.decodeGatewayEmbeddedTarget(originalUrl) != null) {
      return originalUrl;
    }
    if (originalUrl.startsWith('http://localhost') ||
        originalUrl.startsWith('http://127.0.0.1')) {
      return originalUrl;
    }
    return gateway.getProxiedUrl(originalUrl);
  }
  return originalUrl;
}
