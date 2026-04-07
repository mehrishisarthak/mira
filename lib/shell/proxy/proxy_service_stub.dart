import 'package:mira/core/services/proxy_service.dart';

class StubProxyService implements ProxyService {
  @override
  ProxyRuntimeBackend get runtimeBackend => ProxyRuntimeBackend.none;

  @override
  int? get port => null;

  @override
  bool get isRunning => false;

  @override
  String getProxiedUrl(String targetUrl) => targetUrl;

  @override
  String? decodeGatewayEmbeddedTarget(String loaderUrl) => null;

  @override
  Future<void> start(
    String targetProxyUrl, {
    bool allowInsecureCertificates = false,
  }) async {}

  @override
  Future<void> stop() async {}
}
