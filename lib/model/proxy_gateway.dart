import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_proxy/shelf_proxy.dart';
import 'package:mira/model/security_model.dart';

class ProxyGateway {
  HttpServer? _server;
  int? _port;

  int? get port => _port;
  bool get isRunning => _server != null;

  /// Returns the formatted local URL for proxying.
  /// e.g. http://localhost:1234/https://google.com
  String getProxiedUrl(String targetUrl) {
    if (_port == null) return targetUrl;
    return 'http://localhost:$_port/$targetUrl';
  }

  Future<void> start(String targetProxyUrl) async {
    if (_server != null) await stop();

    const int maxRetries = 3;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        final handler = proxyHandler(targetProxyUrl);
        _server = await io.serve(handler, 'localhost', 0);
        _port = _server!.port;
        
        debugPrint('MIRA_GATEWAY: Local iOS Proxy Gateway started on localhost:$_port -> $targetProxyUrl');
        return; // Success
      } catch (e) {
        retryCount++;
        debugPrint('MIRA_GATEWAY: Start attempt $retryCount failed: $e');
        
        if (retryCount < maxRetries) {
          debugPrint('MIRA_GATEWAY: Retrying in 500ms...');
          await Future.delayed(const Duration(milliseconds: 500));
        } else {
          debugPrint('MIRA_GATEWAY: Maximum retries reached. Gateway failed to start.');
        }
      }
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = null;
    debugPrint('MIRA_GATEWAY: Local iOS Proxy Gateway stopped.');
  }
}

// Provider for the ProxyGateway
final proxyGatewayProvider = Provider<ProxyGateway>((ref) => ProxyGateway());

// Notifier to manage the gateway lifecycle based on security settings
class ProxyGatewayNotifier extends StateNotifier<bool> {
  final Ref _ref;
  final ProxyGateway _gateway;
  String? _previousProxyUrl;

  ProxyGatewayNotifier(this._ref, this._gateway) : super(false) {
    // Listen to security settings and toggle the gateway
    _ref.listen(securityProvider, (previous, next) {
      _syncGateway(next);
    });
    
    // Initial sync
    _syncGateway(_ref.read(securityProvider));
  }

  Future<void> _syncGateway(SecurityState security) async {
    // We only need the gateway on iOS (or if we want a universal solution)
    final bool shouldRun = security.isProxyEnabled && 
                           security.proxyUrl.isNotEmpty && 
                           defaultTargetPlatform == TargetPlatform.iOS;

    if (shouldRun && !_gateway.isRunning) {
      await _gateway.start(security.proxyUrl);
      _previousProxyUrl = security.proxyUrl;
      state = true;
    } else if (!shouldRun && _gateway.isRunning) {
      await _gateway.stop();
      state = false;
    } else if (shouldRun && _gateway.isRunning && _previousProxyUrl != security.proxyUrl) {
      // Restart if proxy URL changed
      await _gateway.start(security.proxyUrl);
      _previousProxyUrl = security.proxyUrl;
      state = true;
    }
  }
}

final proxyGatewayStatusProvider = StateNotifierProvider<ProxyGatewayNotifier, bool>((ref) {
  final gateway = ref.watch(proxyGatewayProvider);
  return ProxyGatewayNotifier(ref, gateway);
});
