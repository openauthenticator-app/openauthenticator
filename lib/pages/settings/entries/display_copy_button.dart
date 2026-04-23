import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/settings/display_copy_button.dart';
import 'package:open_authenticator/pages/settings/entries/widgets.dart';

/// Allows to configure [displayCopyButtonSettingsEntryProvider].
class DisplayCopyButtonSettingsEntryWidget extends BoolSettingsEntryWidget<DisplayCopyButtonSettingsEntry> {
  /// Creates a display copy icon settings entry widget instance.
  DisplayCopyButtonSettingsEntryWidget({
    super.key,
  }) : super(
         provider: displayCopyButtonSettingsEntryProvider,
         title: translations.settings.application.displayCopyIconButton.title,
         subtitle: translations.settings.application.displayCopyIconButton.subtitle,
         icon: FIcons.copy,
       );
}
