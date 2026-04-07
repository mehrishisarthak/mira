import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mira/core/services/proxy_service.dart';
import 'package:mira/shell/proxy/mira_ios_gateway_url.dart';

class IOSProxyService implements ProxyService {
  HttpServer? _server;
  HttpClient? _client;
  int? _port;

  final Map<String, String> _tokenToTargetUrl = {};
  final Queue<String> _tokenInsertOrder = Queue<String>();

  static const int _maxTokenEntries = 512;
  static const String _tokenPathPrefix = '$kMiraIosGatewayPath/t/';

  static const Set<String> _hopByHopRequestHeaders = {
    'connection',
    'keep-alive',
    'proxy-authenticate',
    'proxy-authorization',
    'te',
    'trailer',
    'transfer-encoding',
    'upgrade',
  };

  @override
  ProxyRuntimeBackend get runtimeBackend => ProxyRuntimeBackend.iosLocalGateway;

  @override
  int? get port => _port;

  @override
  bool get isRunning => _server != null;

  @override
  String getProxiedUrl(String targetUrl) {
    if (_port == null) return targetUrl;
    if (decodeGatewayEmbeddedTarget(targetUrl) != null) return targetUrl;
    final queryForm = buildMiraIosGatewayLoaderUrl(_port!, targetUrl);
    if (queryForm.length <= kMiraIosGatewayMaxLoaderUrlLength) {
      return queryForm;
    }
    final token = _registerToken(targetUrl);
    return buildMiraIosGatewayTokenLoaderUrl(_port!, token);
  }

  @override
  String? decodeGatewayEmbeddedTarget(String loaderUrl) {
    final u = Uri.tryParse(loaderUrl);
    if (u == null) return null;
    if (u.host != '127.0.0.1' && u.host != 'localhost') return null;

    final path = u.path;
    if (path.startsWith(_tokenPathPrefix)) {
      final token = path.substring(_tokenPathPrefix.length);
      if (token.isEmpty) return null;
      return _tokenToTargetUrl[token];
    }
    if (path == kMiraIosGatewayPath) {
      final raw = u.queryParameters['url'];
      if (raw == null || raw.isEmpty) return null;
      return raw;
    }
    return null;
  }

  @override
  Future<void> start(
    String targetProxyUrl, {
    bool allowInsecureCertificates = false,
  }) async {
    if (_server != null) await stop();

    const int maxRetries = 3;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        final proxyUri = _parseProxyUri(targetProxyUrl);
        final client = HttpClient();
        client.userAgent = 'Mira-iOS-Gateway';
        client.badCertificateCallback = allowInsecureCertificates
            ? (X509Certificate cert, String host, int port) => true
            : null;
        client.findProxy = (uri) => _findProxyLine(proxyUri);
        if (proxyUri.userInfo.isNotEmpty) {
          final userInfo = proxyUri.userInfo;
          final idx = userInfo.indexOf(':');
          final user = Uri.decodeComponent(
            idx >= 0 ? userInfo.substring(0, idx) : userInfo,
          );
          final pass = idx >= 0
              ? Uri.decodeComponent(userInfo.substring(idx + 1))
              : '';
          final port = proxyUri.hasPort
              ? proxyUri.port
              : _defaultPortForScheme(proxyUri.scheme);
          client.addProxyCredentials(
            proxyUri.host,
            port,
            '',
            HttpClientBasicCredentials(user, pass),
          );
        }

        _client = client;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen(
          (request) => unawaited(_handleRequest(request, client)),
          onError: (Object e, StackTrace st) {
            debugPrint('MIRA_GATEWAY: server error: $e\n$st');
          },
        );
        _server = server;
        _port = server.port;

        debugPrint(
          'MIRA_GATEWAY: Local iOS Proxy Gateway started on 127.0.0.1:$_port '
          '-> $targetProxyUrl (allowInsecureCerts=$allowInsecureCertificates)',
        );
        return;
      } catch (e, st) {
        retryCount++;
        debugPrint('MIRA_GATEWAY: Start attempt $retryCount failed: $e\n$st');

        await stop();

        if (retryCount < maxRetries) {
          debugPrint('MIRA_GATEWAY: Retrying in 500ms...');
          await Future<void>.delayed(const Duration(milliseconds: 500));
        } else {
          debugPrint('MIRA_GATEWAY: Maximum retries reached. Gateway failed to start.');
        }
      }
    }
  }

  Future<void> _handleRequest(HttpRequest request, HttpClient client) async {
    final path = request.uri.path;
    if (!path.startsWith(kMiraIosGatewayPath)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final targetString = _resolveTargetString(request);
    if (targetString == null || targetString.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    Uri target;
    try {
      target = Uri.parse(targetString);
    } catch (_) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }
    if (!target.hasScheme) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final scheme = target.scheme.toLowerCase();
    final isWs = request.headers
            .value(HttpHeaders.upgradeHeader)
            ?.toLowerCase() ==
        'websocket';
    if (isWs &&
        request.method == 'GET' &&
        (scheme == 'ws' || scheme == 'wss')) {
      await _proxyWebSocket(request, client, target);
      return;
    }

    if (scheme != 'http' && scheme != 'https') {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    HttpClientRequest? outgoing;
    try {
      outgoing = await client.openUrl(request.method, target);
      outgoing.followRedirects = false;

      request.headers.forEach((String name, List<String> values) {
        final lower = name.toLowerCase();
        if (_hopByHopRequestHeaders.contains(lower)) return;
        if (lower == 'host') return;
        for (final v in values) {
          outgoing!.headers.add(name, v);
        }
      });
      outgoing.headers.set(HttpHeaders.hostHeader, target.authority);

      await outgoing.addStream(request);
      final incoming = await outgoing.close();

      request.response.statusCode = incoming.statusCode;

      incoming.headers.forEach((String name, List<String> values) {
        final lower = name.toLowerCase();
        if (lower == HttpHeaders.transferEncodingHeader) return;
        if (lower == HttpHeaders.connectionHeader) return;
        for (final v in values) {
          request.response.headers.add(name, v);
        }
      });

      await request.response.addStream(incoming);
      await request.response.close();
    } catch (e, st) {
      debugPrint('MIRA_GATEWAY: forward error: $e\n$st');
      try {
        outgoing?.abort();
        request.response.statusCode = HttpStatus.badGateway;
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _proxyWebSocket(
    HttpRequest request,
    HttpClient client,
    Uri target,
  ) async {
    WebSocket? browserSide;
    WebSocket? originSide;
    try {
      browserSide = await WebSocketTransformer.upgrade(request);
      final protoHeader = request.headers.value('sec-websocket-protocol');
      final protocols = protoHeader == null || protoHeader.isEmpty
          ? null
          : protoHeader
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();

      originSide = await WebSocket.connect(
        target.toString(),
        protocols: protocols,
        customClient: client,
      );

      await _pipeWebSockets(browserSide, originSide);
    } catch (e, st) {
      debugPrint('MIRA_GATEWAY: websocket error: $e\n$st');
      try {
        await browserSide?.close();
        await originSide?.close();
      } catch (_) {}
      if (browserSide == null) {
        try {
          request.response.statusCode = HttpStatus.badGateway;
          await request.response.close();
        } catch (_) {}
      }
    }
  }

  Future<void> _pipeWebSockets(WebSocket a, WebSocket b) async {
    try {
      await Future.wait<void>([
        b.addStream(a),
        a.addStream(b),
      ]);
    } catch (e) {
      debugPrint('MIRA_GATEWAY: websocket pipe ended: $e');
    } finally {
      try {
        await a.close();
      } catch (_) {}
      try {
        await b.close();
      } catch (_) {}
    }
  }

  String? _resolveTargetString(HttpRequest request) {
    final path = request.uri.path;
    if (path.startsWith(_tokenPathPrefix)) {
      final token = path.substring(_tokenPathPrefix.length);
      if (token.isEmpty) return null;
      return _tokenToTargetUrl[token];
    }
    if (path == kMiraIosGatewayPath) {
      return request.uri.queryParameters['url'];
    }
    return null;
  }

  String _registerToken(String targetUrl) {
    while (_tokenToTargetUrl.length >= _maxTokenEntries) {
      final oldest = _tokenInsertOrder.removeFirst();
      _tokenToTargetUrl.remove(oldest);
    }
    final token = _randomToken();
    _tokenInsertOrder.addLast(token);
    _tokenToTargetUrl[token] = targetUrl;
    return token;
  }

  String _randomToken() {
    final bytes = List<int>.generate(18, (_) => Random.secure().nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  @override
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = null;
    _client?.close(force: true);
    _client = null;
    _tokenToTargetUrl.clear();
    _tokenInsertOrder.clear();
    debugPrint('MIRA_GATEWAY: Local iOS Proxy Gateway stopped.');
  }
}

String _findProxyLine(Uri proxyUri) {
  final h = proxyUri.host;
  final p = proxyUri.hasPort
      ? proxyUri.port
      : _defaultPortForScheme(proxyUri.scheme);
  final scheme = proxyUri.scheme.toLowerCase();
  if (scheme == 'socks5' || scheme == 'socks') {
    return 'SOCKS5 $h:$p';
  }
  if (scheme == 'socks4') {
    return 'SOCKS4 $h:$p';
  }
  return 'PROXY $h:$p';
}

Uri _parseProxyUri(String raw) {
  var s = raw.trim();
  if (s.isEmpty) {
    throw FormatException('Empty proxy URL');
  }
  if (!s.contains('://')) {
    s = 'http://$s';
  }
  final u = Uri.parse(s);
  if (u.host.isEmpty) {
    throw FormatException('Invalid proxy URL: $raw');
  }
  return u;
}

int _defaultPortForScheme(String scheme) {
  final lower = scheme.toLowerCase();
  if (lower == 'https' || lower == 'wss') return 443;
  if (lower == 'socks' || lower == 'socks5' || lower == 'socks4') return 1080;
  return 80;
}
