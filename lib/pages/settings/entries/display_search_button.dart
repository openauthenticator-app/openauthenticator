import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/settings/display_search_button.dart';
import 'package:open_authenticator/pages/settings/entries/widgets.dart';

/// Allows to configure [displaySearchButtonSettingsEntryProvider].
class DisplaySearchButtonSettingsEntryWidget extends BoolSettingsEntryWidget<DisplaySearchButtonSettingsEntry> {
  /// Creates a display search icon settings entry widget instance.
  DisplaySearchButtonSettingsEntryWidget({
    super.key,
  }) : super(
         provider: displaySearchButtonSettingsEntryProvider,
         title: translations.settings.application.displaySearchIconButton.title,
         subtitle: translations.settings.application.displaySearchIconButton.subtitle,
         icon: FIcons.search,
       );
}
