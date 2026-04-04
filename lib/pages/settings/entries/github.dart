import 'package:forui/forui.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/pages/settings/entries/widgets.dart';
import 'package:open_authenticator/utils/uri_builder.dart';

/// Takes the user to Github to report bugs, suggest new features, ...
class GithubSettingsEntryWidget extends UriSettingsEntry {
  /// Creates a new Github settings entry widget instance.
  GithubSettingsEntryWidget({
    super.key,
  }) : super(
         icon: FIcons.bug,
         title: translations.settings.about.github.title,
         subtitle: translations.settings.about.github.subtitle,
         uri: UriBuilder.prefix(
           prefix: App.githubRepositoryUrl,
           fragment: 'report-bugs-or-suggest-new-features',
         ).build(),
       );
}
