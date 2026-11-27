import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// 在线音源 URL 策略：HTTP 升级为 HTTPS，拒绝任何降级重定向。
class OnlineAudioUrlPolicy {
  static Uri normalize(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const FormatException('Invalid online audio URL');
    }

    return switch (uri.scheme.toLowerCase()) {
      'https' => uri,
      'http' => uri.replace(
        scheme: 'https',
        port: uri.hasPort ? (uri.port == 80 ? 443 : uri.port) : null,
      ),
      _ => throw const FormatException(
        'Online audio URL must use HTTP or HTTPS',
      ),
    };
  }

  static Uri? resolveRedirect(Uri current, int statusCode, String? location) {
    if (!const {301, 302, 303, 307, 308}.contains(statusCode)) return null;
    if (location == null || location.trim().isEmpty) {
      throw const FormatException('Online audio redirect has no location');
    }

    final target = current.resolve(location.trim());
    if (target.scheme.toLowerCase() != 'https' ||
        target.host.isEmpty ||
        target.userInfo.isNotEmpty) {
      throw const FormatException('Blocked non-HTTPS online audio redirect');
    }
    return target;
  }
}

/// 在线音源 HTTPS-only 转发器。
///
/// 播放器访问 `127.0.0.1` 上的随机 token 路径，转发器再以 HTTPS 访问音源，
/// 支持 Range / If-Range，拒绝 HTTPS 降级重定向。
class OnlineAudioHttpsProxy {
  static const int _maxRedirects = 5;
  static const List<String> _forwardedHeaders = <String>[
    HttpHeaders.acceptHeader,
    HttpHeaders.rangeHeader,
    HttpHeaders.ifRangeHeader,
    HttpHeaders.userAgentHeader,
  ];
  static const List<String> _responseHeaders = <String>[
    HttpHeaders.acceptRangesHeader,
    HttpHeaders.cacheControlHeader,
    HttpHeaders.contentLengthHeader,
    HttpHeaders.contentRangeHeader,
    HttpHeaders.contentTypeHeader,
    HttpHeaders.etagHeader,
    HttpHeaders.expiresHeader,
    HttpHeaders.lastModifiedHeader,
    'icy-br',
    'icy-metaint',
    'icy-name',
  ];

  final String _accessToken = _randomToken();
  final Map<String, _ProxySource> _sources = <String, _ProxySource>{};
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = const Duration(seconds: 30);

  HttpServer? _server;
  StreamSubscription<HttpRequest>? _serverSubscription;
  Future<HttpServer>? _serverStarting;
  bool _closed = false;

  Future<String> register(
    String sourceUrl, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    if (_closed) throw StateError('Online audio proxy is closed');
    final source = OnlineAudioUrlPolicy.normalize(sourceUrl);
    final server = await _ensureServer();
    if (_closed) throw StateError('Online audio proxy is closed');
    final id = _randomToken();
    _sources[id] = _ProxySource(source, Map<String, String>.unmodifiable(headers));
    return Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
      pathSegments: <String>[_accessToken, id],
    ).toString();
  }

  void release(String? proxyUrl) {
    if (proxyUrl == null) return;
    final uri = Uri.tryParse(proxyUrl);
    final segments = uri?.pathSegments;
    if (uri == null ||
        uri.scheme != 'http' ||
        uri.host != InternetAddress.loopbackIPv4.address ||
        uri.port != _server?.port ||
        segments == null ||
        segments.length != 2 ||
        segments.first != _accessToken) {
      return;
    }
    _sources.remove(segments.last);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _sources.clear();
    _client.close(force: true);
    await _serverSubscription?.cancel();
    await _server?.close(force: true);
    _server = null;
  }

  Future<HttpServer> _ensureServer() {
    final server = _server;
    if (server != null) return Future<HttpServer>.value(server);
    return _serverStarting ??= _startServer().whenComplete(() {
      _serverStarting = null;
    });
  }

  Future<HttpServer> _startServer() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    if (_closed) {
      await server.close(force: true);
      throw StateError('Online audio proxy is closed');
    }
    _server = server;
    _serverSubscription = server.listen((HttpRequest request) {
      unawaited(_handle(request));
    });
    return server;
  }

  Future<void> _handle(HttpRequest request) async {
    if (request.connectionInfo?.remoteAddress.isLoopback != true) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }
    if (request.method != 'GET' && request.method != 'HEAD') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      request.response.headers.set(HttpHeaders.allowHeader, 'GET, HEAD');
      await request.response.close();
      return;
    }

    final segments = request.uri.pathSegments;
    if (segments.length != 2 || segments.first != _accessToken) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final source = _sources[segments.last];
    if (source == null) {
      request.response.statusCode = HttpStatus.gone;
      await request.response.close();
      return;
    }

    var responseStarted = false;
    try {
      final upstream = await _openUpstream(request, source);
      request.response.statusCode = upstream.statusCode;
      for (final String name in _responseHeaders) {
        final values = upstream.headers[name];
        if (values == null) continue;
        for (final value in values) {
          request.response.headers.add(name, value);
        }
      }
      responseStarted = true;
      if (request.method == 'HEAD') {
        await upstream.drain<void>();
        await request.response.close();
      } else {
        await upstream.pipe(request.response);
      }
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('[Online audio] HTTPS proxy failed (${error.runtimeType})');
      }
      if (!responseStarted) {
        request.response.statusCode = HttpStatus.badGateway;
        request.response.headers.contentType = ContentType.text;
        request.response.write('ONLINE_HTTPS_STREAM_FAILED');
      }
      await request.response.close();
    }
  }

  Future<HttpClientResponse> _openUpstream(
    HttpRequest incoming,
    _ProxySource source,
  ) async {
    var current = source.uri;
    var redirects = 0;
    while (true) {
      if (kDebugMode) {
        debugPrint(
          '[Online audio] upstream request ${current.scheme}://${current.host}',
        );
      }
      final upstreamRequest = await _client.openUrl(incoming.method, current);
      upstreamRequest.followRedirects = false;
      upstreamRequest.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');

      for (final entry in source.headers.entries) {
        final name = entry.key.toLowerCase();
        if (name == 'host' || name == 'authorization' || name == 'cookie') {
          continue;
        }
        upstreamRequest.headers.set(entry.key, entry.value);
      }
      for (final String name in _forwardedHeaders) {
        final value = incoming.headers.value(name);
        if (value != null) upstreamRequest.headers.set(name, value);
      }

      final upstream = await upstreamRequest.close();
      if (kDebugMode) {
        debugPrint(
          '[Online audio] upstream response '
          '${current.scheme}://${current.host} status=${upstream.statusCode}',
        );
      }
      Uri? next;
      try {
        next = OnlineAudioUrlPolicy.resolveRedirect(
          current,
          upstream.statusCode,
          upstream.headers.value(HttpHeaders.locationHeader),
        );
      } on FormatException catch (error) {
        await upstream.drain<void>();
        if (kDebugMode) {
          debugPrint('[Online audio] redirect rejected: ${error.message}');
        }
        rethrow;
      }
      if (next == null) return upstream;

      if (kDebugMode) {
        debugPrint(
          '[Online audio] HTTPS redirect ${current.host} -> ${next.host}',
        );
      }
      await upstream.drain<void>();
      if (redirects >= _maxRedirects) {
        throw const FormatException('Too many online audio redirects');
      }
      current = next;
      redirects++;
    }
  }

  static String _randomToken() {
    final random = Random.secure();
    return List<String>.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

class _ProxySource {
  const _ProxySource(this.uri, this.headers);

  final Uri uri;
  final Map<String, String> headers;
}
