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

  /// If [loaderUrl] is our iOS gateway wrapper (`?url=` or `/t/…`), returns the
  /// real origin URL; otherwise null. Used to avoid double-wrapping and for the
  /// address bar.
  String? decodeGatewayEmbeddedTarget(String loaderUrl);

  /// Starts the proxy gateway pointing to [targetProxyUrl].
  Future<void> start(
    String targetProxyUrl, {
    bool allowInsecureCertificates = false,
  });

  /// Stops the proxy gateway.
  Future<void> stop();
}
