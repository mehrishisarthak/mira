import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/services/proxy_service.dart';
import 'package:mira/core/entities/security_entity.dart';
import 'package:mira/core/notifiers/security_notifier.dart';
import 'package:mira/shell/proxy/proxy_provider.dart';

/// Notifier to manage the gateway lifecycle based on security settings.
/// State: bool representing if the gateway is running.
class ProxyGatewayNotifier extends StateNotifier<bool> {
  final Ref _ref;
  final ProxyService _service;
  String? _previousProxyUrl;

  ProxyGatewayNotifier(this._ref, this._service) : super(false) {
    // Listen to security settings and toggle the gateway
    _ref.listen(securityProvider, (previous, next) {
      _syncGateway(next);
    });
    
    // Initial sync
    _syncGateway(_ref.read(securityProvider));
  }

  Future<void> _syncGateway(SecurityState security) async {
    final bool shouldRun = security.isProxyEnabled &&
        security.proxyUrl.isNotEmpty &&
        !kIsWeb &&
        _service.runtimeBackend == ProxyRuntimeBackend.iosLocalGateway;

    if (shouldRun && !_service.isRunning) {
      await _service.start(security.proxyUrl);
      _previousProxyUrl = security.proxyUrl;
      if (mounted) state = _service.isRunning;
    } else if (!shouldRun && _service.isRunning) {
      await _service.stop();
      if (mounted) state = false;
    } else if (shouldRun && _service.isRunning && _previousProxyUrl != security.proxyUrl) {
      // Restart if proxy URL changed
      await _service.start(security.proxyUrl);
      _previousProxyUrl = security.proxyUrl;
      if (mounted) state = _service.isRunning;
    }
  }
}

final proxyGatewayStatusProvider = StateNotifierProvider<ProxyGatewayNotifier, bool>((ref) {
  final service = ref.watch(proxyServiceProvider);
  return ProxyGatewayNotifier(ref, service);
});

