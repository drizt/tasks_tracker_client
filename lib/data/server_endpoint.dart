const _defaultServerPort = 3000;
const _serverWebSocketPath = '/ws';

Uri defaultServerWebSocketUri({
  Uri? baseUri,
  String configured = const String.fromEnvironment('TASKS_TRACKER_SERVER'),
}) {
  if (configured.isNotEmpty) {
    return Uri.parse(configured);
  }

  final base = baseUri ?? Uri.base;
  final scheme = _webSocketSchemeFor(base);

  if (base.host.isEmpty) {
    return _serverWebSocketUri(
      scheme: scheme,
      host: 'localhost',
      port: _defaultServerPort,
    );
  }

  return _serverWebSocketUri(
    scheme: scheme,
    host: base.host,
    port: _isLoopbackHost(base.host)
        ? _defaultServerPort
        : (base.hasPort ? base.port : null),
  );
}

String _webSocketSchemeFor(Uri uri) {
  return uri.scheme == 'https' ? 'wss' : 'ws';
}

bool _isLoopbackHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '::1';
}

Uri _serverWebSocketUri({
  required String scheme,
  required String host,
  int? port,
}) {
  return Uri(
    scheme: scheme,
    host: host,
    port: port ?? 0,
    path: _serverWebSocketPath,
  );
}
