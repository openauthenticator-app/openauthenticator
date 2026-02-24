import 'package:flutter/material.dart' hide AboutDialog;
import 'package:forui/forui.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/pages/settings/entries/widgets.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/about_dialog.dart';
import 'package:open_authenticator/widgets/sized_scalable_image.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Shows various info about the app.
class AboutSettingsEntryWidget extends StatelessWidget with FTileMixin {
  /// Creates a new about settings entry widget instance.
  const AboutSettingsEntryWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
    future: PackageInfo.fromPlatform(),
    initialData: _DefaultPackageInfo(),
    builder: (context, snapshot) => ClickableTile(
      suffix: const RightChevronSuffix(),
      prefix: const Icon(FIcons.heart),
      title: Text(translations.settings.about.aboutApp.title(appName: App.appName)),
      subtitle: Text.rich(
        translations.settings.about.aboutApp.subtitle(
          appName: const TextSpan(
            text: App.appName,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
          appVersion: TextSpan(
            text: snapshot.data!.version,
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
          appAuthor: const TextSpan(
            text: App.appAuthor,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      ),
      enabled: snapshot.data is! _DefaultPackageInfo,
      onPress: () => AboutAppDialog.show(
        context,
        applicationName: App.appName,
        applicationVersion: 'v${snapshot.data!.version}',
        applicationIcon: const SizedScalableImage(
          asset: 'assets/images/logo.si',
          height: 90,
          width: 90,
        ),
        applicationLegalese: translations.settings.about.aboutApp.dialogLegalese(
          appName: App.appName,
          appAuthor: App.appAuthor,
        ),
      ),
    ),
  );
}

/// The default package info.
class _DefaultPackageInfo extends PackageInfo {
  /// Creates a new default package info instance.
  _DefaultPackageInfo()
    : super(
        appName: App.appName,
        packageName: App.appPackageName,
        version: '1.0.0',
        buildNumber: '1',
      );
}
