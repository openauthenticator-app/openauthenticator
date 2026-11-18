import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/core/settings/entry.dart';

/// The display copy icon settings entry provider.
final AsyncNotifierProvider<DisplayCopyButtonSettingsEntry, bool> displayCopyButtonSettingsEntryProvider = AsyncNotifierProvider.autoDispose<DisplayCopyButtonSettingsEntry, bool>(DisplayCopyButtonSettingsEntry.new);

/// A settings entry that allows to display or hide the copy icon.
class DisplayCopyButtonSettingsEntry extends SettingsEntry<bool> {
  /// Creates a new display copy icon settings entry instance.
  DisplayCopyButtonSettingsEntry()
    : super(
        key: 'displayCopyButton',
        defaultValue: true,
      );
}
