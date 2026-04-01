import 'package:mira/core/services/proxy_service.dart';

class StubProxyService implements ProxyService {
  @override
  int? get port => null;

  @override
  bool get isRunning => false;

  @override
  String getProxiedUrl(String targetUrl) => targetUrl;

  @override
  Future<void> start(String targetProxyUrl) async {}

  @override
  Future<void> stop() async {}
}
