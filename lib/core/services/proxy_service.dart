/// Where the in-app HTTP proxy tunnel is implemented.
///
/// Today only iOS runs a real local gateway ([ProxyRuntimeBackend.iosLocalGateway]);
/// other platforms use a no-op stub so the same security UI compiles everywhere.
enum ProxyRuntimeBackend {
  iosLocalGateway,
  none,
}

abstract class ProxyService {
  int? get port;
  bool get isRunning;

  /// Which platform build backs this instance (see [ProxyRuntimeBackend]).
  ProxyRuntimeBackend get runtimeBackend;

  /// Returns the formatted local URL for proxying.
  String getProxiedUrl(String targetUrl);

  /// Starts the proxy gateway pointing to [targetProxyUrl].
  Future<void> start(String targetProxyUrl);

  /// Stops the proxy gateway.
  Future<void> stop();
}
