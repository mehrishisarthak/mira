/// Local iOS gateway loads pages under this path; the real origin is in `?url=`
/// or a short `/t/<token>` segment (see [IOSProxyService]).
const kMiraIosGatewayPath = '/__mira_proxy';

/// Prefer query form when the full loader URL stays under typical WebView limits.
const kMiraIosGatewayMaxLoaderUrlLength = 1600;

String buildMiraIosGatewayLoaderUrl(int port, String targetUrl) {
  return 'http://127.0.0.1:$port$kMiraIosGatewayPath'
      '?url=${Uri.encodeComponent(targetUrl)}';
}

String buildMiraIosGatewayTokenLoaderUrl(int port, String token) {
  return 'http://127.0.0.1:$port$kMiraIosGatewayPath/t/$token';
}
