import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_proxy/shelf_proxy.dart';
import 'package:mira/core/services/proxy_service.dart';

class IOSProxyService implements ProxyService {
  HttpServer? _server;
  int? _port;

  @override
  ProxyRuntimeBackend get runtimeBackend => ProxyRuntimeBackend.iosLocalGateway;

  @override
  int? get port => _port;

  @override
  bool get isRunning => _server != null;

  @override
  String getProxiedUrl(String targetUrl) {
    if (_port == null) return targetUrl;
    // Don't proxy the proxy itself
    if (targetUrl.startsWith('http://localhost:$_port')) return targetUrl;
    return 'http://localhost:$_port/$targetUrl';
  }

  @override
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

  @override
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = null;
    debugPrint('MIRA_GATEWAY: Local iOS Proxy Gateway stopped.');
  }
}
