import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/core/settings/entry.dart';

/// The show intro settings entry provider.
final AsyncNotifierProvider<ShowIntroSettingsEntry, bool> showIntroSettingsEntryProvider = AsyncNotifierProvider.autoDispose<ShowIntroSettingsEntry, bool>(ShowIntroSettingsEntry.new);

/// A settings entry that allows to display the intro page.
class ShowIntroSettingsEntry extends SettingsEntry<bool> {
  /// Creates a new show intro settings entry instance.
  ShowIntroSettingsEntry()
    : super(
        key: 'showIntro',
        defaultValue: true,
      );
}
