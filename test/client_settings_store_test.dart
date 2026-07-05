import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_tracker_client/data/client_settings.dart';
import 'package:tasks_tracker_client/data/client_settings_store_io.dart';

void main() {
  test('returns empty settings when the file is absent', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'tasks-tracker-client-settings-',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final store = FileClientSettingsStore(
      file: File('${tempDir.path}/settings.json'),
    );

    final settings = await store.load();

    expect(settings.serverUri, isNull);
  });

  test('saves and loads the server websocket url', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'tasks-tracker-client-settings-',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final store = FileClientSettingsStore(
      file: File('${tempDir.path}/nested/settings.json'),
    );

    await store.save(
      ClientSettings(serverUri: Uri.parse('wss://tasks.example.test/ws')),
    );

    final settings = await store.load();

    expect(settings.serverUri.toString(), 'wss://tasks.example.test/ws');
  });

  test('normalizes saved server urls when loading settings', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'tasks-tracker-client-settings-',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final file = File('${tempDir.path}/settings.json');
    await file.writeAsString('{"serverWebSocketUrl":"localhost:3000"}');
    final store = FileClientSettingsStore(file: file);

    final settings = await store.load();

    expect(settings.serverUri.toString(), 'ws://localhost:3000/ws');
  });
}
