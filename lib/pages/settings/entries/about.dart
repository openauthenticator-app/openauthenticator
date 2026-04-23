import 'package:flutter/material.dart' hide AboutDialog;
import 'package:forui/forui.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/pages/settings/entries/widgets.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/about_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Shows various info about the app.
class AboutSettingsEntryWidget extends StatelessWidget with FTileMixin {
  /// Creates a new about settings entry widget instance.
  const AboutSettingsEntryWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) => ClickableTile(
    suffix: const RightChevronSuffix(),
    prefix: const Icon(FIcons.heart),
    title: Text(translations.settings.about.aboutApp.title(appName: App.appName)),
    subtitle: FutureBuilder(
      future: PackageInfo.fromPlatform().then((value) => value.version),
      builder: (context, snapshot) => Text.rich(
        translations.settings.about.aboutApp.subtitle(
          appName: const TextSpan(
            text: App.appName,
            style: TextStyle(fontStyle: .italic),
          ),
          appVersion: TextSpan(
            text: snapshot.data ?? '1.0.0',
            style: const TextStyle(fontStyle: .italic),
          ),
          appAuthor: const TextSpan(
            text: App.appAuthor,
            style: TextStyle(fontStyle: .italic),
          ),
        ),
      ),
    ),
    onPress: () => AboutAppDialog.showForApp(context),
  );
}
