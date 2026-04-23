import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/settings/cache_totp_pictures.dart';
import 'package:open_authenticator/pages/settings/entries/widgets.dart';

/// Allows to configure [cacheTotpPicturesSettingsEntryProvider].
class CacheTotpPicturesSettingsEntryWidget extends BoolSettingsEntryWidget<CacheTotpPicturesSettingsEntry> {
  /// Creates a new cache TOTP pictures settings entry widget instance.
  CacheTotpPicturesSettingsEntryWidget({
    super.key,
  }) : super(
         provider: cacheTotpPicturesSettingsEntryProvider,
         title: translations.settings.application.cacheTotpPictures.title,
         subtitle: translations.settings.application.cacheTotpPictures.subtitle,
         icon: FIcons.server,
       );
}
