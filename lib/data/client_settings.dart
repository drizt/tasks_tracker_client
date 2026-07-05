class ClientSettings {
  const ClientSettings({this.serverUri});

  final Uri? serverUri;
}

abstract interface class ClientSettingsStore {
  Future<ClientSettings> load();
  Future<void> save(ClientSettings settings);
}
