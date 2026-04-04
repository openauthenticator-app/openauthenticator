import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/pages/settings/entries/about.dart';
import 'package:open_authenticator/pages/settings/entries/backup_now.dart';
import 'package:open_authenticator/pages/settings/entries/cache_totp_pictures.dart';
import 'package:open_authenticator/pages/settings/entries/change_backend_url.dart';
import 'package:open_authenticator/pages/settings/entries/change_master_password.dart';
import 'package:open_authenticator/pages/settings/entries/clear_data.dart';
import 'package:open_authenticator/pages/settings/entries/confirm_email.dart';
import 'package:open_authenticator/pages/settings/entries/contributor_plan.dart';
import 'package:open_authenticator/pages/settings/entries/contributor_plan_state.dart';
import 'package:open_authenticator/pages/settings/entries/delete_account.dart';
import 'package:open_authenticator/pages/settings/entries/display_copy_button.dart';
import 'package:open_authenticator/pages/settings/entries/display_search_button.dart';
import 'package:open_authenticator/pages/settings/entries/enable_local_auth.dart';
import 'package:open_authenticator/pages/settings/entries/github.dart';
import 'package:open_authenticator/pages/settings/entries/link_input.dart';
import 'package:open_authenticator/pages/settings/entries/link_provider.dart';
import 'package:open_authenticator/pages/settings/entries/locale.dart';
import 'package:open_authenticator/pages/settings/entries/log_in.dart';
import 'package:open_authenticator/pages/settings/entries/manage_backups.dart';
import 'package:open_authenticator/pages/settings/entries/migration_state.dart';
import 'package:open_authenticator/pages/settings/entries/save_derived_key.dart';
import 'package:open_authenticator/pages/settings/entries/show_intro_page.dart';
import 'package:open_authenticator/pages/settings/entries/synchronize.dart';
import 'package:open_authenticator/pages/settings/entries/theme.dart';
import 'package:open_authenticator/pages/settings/entries/translate.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/utils/platform.dart';
import 'package:open_authenticator/widgets/app_scaffold.dart';
import 'package:open_authenticator/widgets/clickable.dart';

/// Allows to configure the app.
class SettingsPage extends ConsumerWidget {
  /// The settings page name.
  static const String name = '/settings';

  /// Creates a new settings page instance.
  const SettingsPage({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTextStyle(
    maxLines: 10,
    style: const TextStyle(),
    child: AppScaffold.scrollable(
      header: FHeader.nested(
        prefixes: [
          ClickableHeaderAction.back(
            onPress: () => Navigator.pop(context),
          ),
        ],
        title: Text(translations.settings.title),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: kSpace),
          child: FTileGroup(
            label: Text(translations.settings.application.title),
            children: [
              const ContributorPlanEntryWidget(),
              const ThemeSettingsEntryWidget(),
              CacheTotpPicturesSettingsEntryWidget(),
              if (currentPlatform.isMobile || kDebugMode) //
              ...[
                DisplayCopyButtonSettingsEntryWidget(),
                DisplaySearchButtonSettingsEntryWidget(),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: kSpace),
          child: FTileGroup(
            label: Text(translations.settings.security.title),
            children: [
              EnableLocalAuthSettingsEntryWidget(),
              SaveDerivedKeySettingsEntryWidget(),
              const ChangeMasterPasswordSettingsEntryWidget(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: kSpace),
          child: FTileGroup(
            label: Text(translations.settings.synchronization.title),
            children: [
              const ConfirmEmailSettingsEntryWidget(),
              const AccountLinkSettingsEntryWidget(),
              SynchronizeSettingsEntryWidget(),
              const AccountLogInSettingsEntryWidget(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: kSpace),
          child: FTileGroup(
            label: Text(translations.settings.backups.title),
            children: [
              const BackupNowSettingsEntryWidget(),
              const ManageBackupSettingsEntryWidget(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: kSpace),
          child: FTileGroup(
            label: Text(translations.settings.about.title),
            children: [
              TranslateSettingsEntryWidget(),
              GithubSettingsEntryWidget(),
              const AboutSettingsEntryWidget(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: kDebugMode ? kSpace : 0),
          child: FTileGroup(
            style: .delta(
              labelTextStyle: .delta([
                .all(
                  .delta(color: context.theme.colors.destructive),
                ),
              ]),
              tileStyles: .delta([
                .all(
                  .delta(
                    contentStyle: .delta(
                      prefixIconStyle: .delta(
                        [
                          .all(
                            .delta(color: context.theme.colors.destructive),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
            ),
            label: Text(translations.settings.dangerZone.title),
            children: [
              const ChangeBackendUrlSettingsEntryWidget(),
              const DeleteAccountSettingsEntryWidget(),
              const ClearDataSettingsEntryWidget(),
            ],
          ),
        ),
        if (kDebugMode)
          FTileGroup(
            label: const Text('Debug'),
            children: [
              const ShowIntroPageSettingsEntryWidget(),
              const ContributorPlanStateSettingsEntryWidget(),
              const MigrationStateSettingsEntryWidget(),
              const LocaleSettingsEntryWidget(),
              const LinkInputSettingsEntryWidget(),
            ],
          ),
      ],
    ),
  );
}
