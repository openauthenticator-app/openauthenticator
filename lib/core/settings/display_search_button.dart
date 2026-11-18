import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/core/settings/entry.dart';

/// The display search button settings entry provider.
final AsyncNotifierProvider<DisplaySearchButtonSettingsEntry, bool> displaySearchButtonSettingsEntryProvider = AsyncNotifierProvider.autoDispose<DisplaySearchButtonSettingsEntry, bool>(DisplaySearchButtonSettingsEntry.new);

/// A settings entry that allows to control whether to show a search button in the app bar.
class DisplaySearchButtonSettingsEntry extends SettingsEntry<bool> {
  /// Creates a new display search button settings entry instance.
  DisplaySearchButtonSettingsEntry()
    : super(
        key: 'displaySearchButton',
        defaultValue: true,
      );
}
