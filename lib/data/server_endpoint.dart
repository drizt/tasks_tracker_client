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

Uri normalizeServerWebSocketUri(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('Server URL is required');
  }

  final source = _hasUriScheme(trimmed) ? trimmed : 'ws://$trimmed';
  final uri = Uri.tryParse(source);
  if (uri == null || uri.host.isEmpty) {
    throw const FormatException('Enter a valid server URL');
  }

  final scheme = switch (uri.scheme.toLowerCase()) {
    'ws' => 'ws',
    'wss' => 'wss',
    'http' => 'ws',
    'https' => 'wss',
    _ => throw const FormatException(
      'Server URL must use ws, wss, http, or https',
    ),
  };
  final path = uri.path.isEmpty || uri.path == '/'
      ? _serverWebSocketPath
      : uri.path;

  return Uri(
    scheme: scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : 0,
    path: path,
    query: uri.query,
  );
}

bool _hasUriScheme(String value) {
  return RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*://').hasMatch(value);
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
