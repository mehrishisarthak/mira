abstract class ProxyService {
  int? get port;
  bool get isRunning;

  /// Returns the formatted local URL for proxying.
  String getProxiedUrl(String targetUrl);

  /// Starts the proxy gateway pointing to [targetProxyUrl].
  Future<void> start(String targetProxyUrl);

  /// Stops the proxy gateway.
  Future<void> stop();
}
