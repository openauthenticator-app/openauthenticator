import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/core/release_update.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/utils/clipboard.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Offers a download when a newer GitHub release is available at startup.
class ReleaseUpdateNotice extends StatefulWidget {
  /// The GitHub asset name embedded in direct-download builds.
  static const String assetName = String.fromEnvironment('GITHUB_RELEASE_ASSET');

  /// The app content.
  final Widget child;

  /// Creates a startup update notice.
  const ReleaseUpdateNotice({
    super.key,
    required this.child,
  });

  @override
  State<ReleaseUpdateNotice> createState() => _ReleaseUpdateNoticeState();
}

/// The release update notice widget state.
/// The release update notice state.
class _ReleaseUpdateNoticeState extends State<ReleaseUpdateNotice> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkForUpdate();
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;

  /// Checks the installed version and shows a toast if an update is ready.
  Future<void> _checkForUpdate() async {
    final http.Client client = http.Client();
    final ReleaseUpdate? update;
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      update = await findReleaseUpdate(
        client: client,
        repository: Uri.parse(App.githubRepositoryUrl),
        installedVersion: packageInfo.version,
        assetName: ReleaseUpdateNotice.assetName,
      );
    } on PlatformException {
      return;
    } finally {
      client.close();
    }
    if (!mounted || update == null) {
      return;
    }

    final (:String version, :Uri downloadsPage) = update;
    showFToast(
      context: context,
      title: Text(translations.miscellaneous.updateAvailable(version: version)),
      icon: const Icon(FLucideIcons.download),
      description: ClickableButton(
        variant: .outline,
        mainAxisSize: .min,
        onPress: () => _openDownloads(downloadsPage),
        child: ButtonText(
          translations.miscellaneous.openDownloads,
          maxLines: 2,
          flexibleBreakpoint: double.infinity,
        ),
      ),
      suffixBuilder: (context, entry) => Tooltip(
        message: MaterialLocalizations.of(context).closeButtonLabel,
        child: ClickableButton.icon(
          variant: .ghost,
          onPress: entry.dismiss,
          child: const Icon(FLucideIcons.x),
        ),
      ),
      duration: const Duration(seconds: 20),
    );
  }

  /// Opens the release page or copies its URL if the browser cannot open it.
  Future<void> _openDownloads(Uri url) async {
    try {
      if (await launchUrl(url, mode: LaunchMode.externalApplication)) {
        return;
      }
    } on PlatformException {
      // Let the user open the link manually.
    }
    if (mounted) {
      await copyText(context, url.toString(), confirmation: translations.miscellaneous.urlCopiedToClipboard);
    }
  }
}
