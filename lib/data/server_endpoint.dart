Uri defaultServerWebSocketUri({Uri? baseUri}) {
  const configured = String.fromEnvironment('TASKS_TRACKER_SERVER');
  if (configured.isNotEmpty) {
    return Uri.parse(configured);
  }

  final base = baseUri ?? Uri.base;
  final scheme = switch (base.scheme) {
    'https' => 'wss',
    'http' => 'ws',
    _ => 'ws',
  };

  if (base.host.isEmpty) {
    return Uri.parse('ws://localhost:3000/ws');
  }

  return base.replace(scheme: scheme, path: '/ws', query: '');
}
