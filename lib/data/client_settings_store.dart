import 'client_settings.dart';
import 'client_settings_store_stub.dart'
    if (dart.library.io) 'client_settings_store_io.dart'
    as platform;

ClientSettingsStore createClientSettingsStore() {
  return platform.createClientSettingsStore();
}
