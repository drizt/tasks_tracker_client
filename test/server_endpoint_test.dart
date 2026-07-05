import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_tracker_client/data/server_endpoint.dart';

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
      baseUri: Uri.parse(
        'file:///home/taurus/tasks_tracker/tasks_tracker_client/',
      ),
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

  test('normalizes a bare server host to the default websocket path', () {
    final uri = normalizeServerWebSocketUri('localhost:3000');

    expect(uri.toString(), 'ws://localhost:3000/ws');
  });

  test('normalizes http server urls to websocket urls', () {
    final uri = normalizeServerWebSocketUri('https://tasks.example.test');

    expect(uri.toString(), 'wss://tasks.example.test/ws');
  });

  test('keeps an explicit websocket path', () {
    final uri = normalizeServerWebSocketUri('wss://tasks.example.test/rpc');

    expect(uri.toString(), 'wss://tasks.example.test/rpc');
  });

  test('rejects unsupported server url schemes', () {
    expect(
      () => normalizeServerWebSocketUri('ftp://tasks.example.test/ws'),
      throwsFormatException,
    );
  });
}
