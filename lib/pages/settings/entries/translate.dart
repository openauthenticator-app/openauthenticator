import 'package:forui/forui.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/pages/settings/entries/widgets.dart';

/// Takes the user to the app translation page.
class TranslateSettingsEntryWidget extends UriSettingsEntry with FTileMixin {
  /// Creates a new translate settings entry widget instance.
  TranslateSettingsEntryWidget({
    super.key,
  }) : super(
         icon: FIcons.languages,
         title: translations.settings.about.translate.title,
         subtitle: translations.settings.about.translate.subtitle(appName: App.appName),
         uri: Uri.parse(App.appTranslationUrl),
       );
}
