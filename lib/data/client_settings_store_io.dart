import 'dart:convert';
import 'dart:io';

import 'client_settings.dart';
import 'server_endpoint.dart';

const _serverWebSocketUrlKey = 'serverWebSocketUrl';

ClientSettingsStore createClientSettingsStore() {
  return FileClientSettingsStore(file: defaultClientSettingsFile());
}

File defaultClientSettingsFile() {
  final configHome = Platform.environment['XDG_CONFIG_HOME'];
  final home = Platform.environment['HOME'];
  final configRoot = configHome != null && configHome.isNotEmpty
      ? configHome
      : home != null && home.isNotEmpty
      ? '$home/.config'
      : Directory.current.path;

  return File('$configRoot/tasks-tracker-client/settings.json');
}

class FileClientSettingsStore implements ClientSettingsStore {
  const FileClientSettingsStore({required this.file});

  final File file;

  @override
  Future<ClientSettings> load() async {
    if (!await file.exists()) {
      return const ClientSettings();
    }

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Client settings must be an object');
    }

    final serverWebSocketUrl = decoded[_serverWebSocketUrlKey];
    if (serverWebSocketUrl == null) {
      return const ClientSettings();
    }

    if (serverWebSocketUrl is! String) {
      throw const FormatException('Client settings server URL must be a text');
    }

    return ClientSettings(
      serverUri: normalizeServerWebSocketUri(serverWebSocketUrl),
    );
  }

  @override
  Future<void> save(ClientSettings settings) async {
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    const encoder = JsonEncoder.withIndent('  ');
    final encoded = encoder.convert({
      if (settings.serverUri != null)
        _serverWebSocketUrlKey: settings.serverUri.toString(),
    });
    await file.writeAsString('$encoded\n');
  }
}
