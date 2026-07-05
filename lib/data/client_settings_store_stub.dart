import 'client_settings.dart';

ClientSettingsStore createClientSettingsStore() {
  return const MemoryClientSettingsStore();
}

class MemoryClientSettingsStore implements ClientSettingsStore {
  const MemoryClientSettingsStore();

  @override
  Future<ClientSettings> load() async {
    return const ClientSettings();
  }

  @override
  Future<void> save(ClientSettings settings) async {}
}
