import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_tracker/data/server_endpoint.dart';

void main() {
  test('uses the configured websocket endpoint when provided', () {
    final uri = defaultServerWebSocketUri(
      configured: 'wss://tasks.example.test/rpc',
      baseUri: Uri.parse('http://localhost:54321/'),
    );

    expect(uri.toString(), 'wss://tasks.example.test/rpc');
  });

  test('uses the local task server when the base uri has no host', () {
    final uri = defaultServerWebSocketUri(
      baseUri: Uri.parse('file:///home/taurus/tasks_tracker/client/'),
    );

    expect(uri.toString(), 'ws://localhost:3000/ws');
  });

  test('uses the local task server from a localhost browser origin', () {
    final uri = defaultServerWebSocketUri(
      baseUri: Uri.parse('http://localhost:54321/'),
    );

    expect(uri.toString(), 'ws://localhost:3000/ws');
  });

  test('keeps the loopback address used by the browser origin', () {
    final uri = defaultServerWebSocketUri(
      baseUri: Uri.parse('http://127.0.0.1:54321/'),
    );

    expect(uri.toString(), 'ws://127.0.0.1:3000/ws');
  });

  test('uses same-origin websocket routing for deployed http builds', () {
    final uri = defaultServerWebSocketUri(
      baseUri: Uri.parse('http://tasks.example.test/app/?debug=true'),
    );

    expect(uri.toString(), 'ws://tasks.example.test/ws');
  });

  test('uses secure same-origin websocket routing for https builds', () {
    final uri = defaultServerWebSocketUri(
      baseUri: Uri.parse('https://tasks.example.test:8443/app/#today'),
    );

    expect(uri.toString(), 'wss://tasks.example.test:8443/ws');
  });
}
