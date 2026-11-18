import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/model/settings/entry.dart';
import 'package:open_authenticator/utils/shared_preferences_with_prefix.dart';

/// The backend URL settings entry provider.
final AsyncNotifierProvider<BackendUrlSettingsEntry, BackendUrl> backendUrlSettingsEntryProvider = AsyncNotifierProvider.autoDispose<BackendUrlSettingsEntry, BackendUrl>(BackendUrlSettingsEntry.new);

/// A settings entry that allows to configure the backend URL.
class BackendUrlSettingsEntry extends SettingsEntry<BackendUrl> {
  /// Creates a new backend URL settings entry instance.
  BackendUrlSettingsEntry()
    : super(
        key: 'backendUrl',
        defaultValue: const BackendUrl(App.defaultBackendUrl),
      );

  @override
  @protected
  Future<BackendUrl> loadFromPreferences(SharedPreferencesWithPrefix preferences) async => BackendUrl(preferences.getString(key)!);

  @override
  @protected
  Future<void> saveToPreferences(SharedPreferencesWithPrefix preferences, BackendUrl value) => preferences.setString(key, value);
}

/// An extension type to allow to check if the backend URL has changed.
extension type const BackendUrl(String backendUrl) implements String {
  /// Returns `true` if the value has changed.
  bool get hasBackendUrlChanged => backendUrl != App.defaultBackendUrl;
}
