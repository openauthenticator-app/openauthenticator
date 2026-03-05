import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/model/settings/entry.dart';

/// The backend URL settings entry provider.
final backendUrlSettingsEntryProvider = AsyncNotifierProvider<BackendUrlSettingsEntry, String>(BackendUrlSettingsEntry.new);

/// A settings entry that allows to configure the backend URL.
class BackendUrlSettingsEntry extends SettingsEntry<String> {
  /// Creates a new backend URL settings entry instance.
  BackendUrlSettingsEntry()
    : super(
        key: 'backendUrl',
        defaultValue: App.defaultBackendUrl,
      );
}

/// Extension methods for the [String] class.
extension HasBackendUrlChanged on String {
  /// Returns true if the value has changed.
  bool get hasBackendUrlChanged => this != App.defaultBackendUrl;
}
