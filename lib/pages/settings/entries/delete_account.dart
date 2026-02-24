import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/backend/user.dart';
import 'package:open_authenticator/model/settings/storage_type.dart';
import 'package:open_authenticator/utils/account.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';
import 'package:open_authenticator/widgets/waiting_overlay.dart';

/// Allows to delete the user account.
class DeleteAccountSettingsEntryWidget extends ConsumerWidget with FTileMixin {
  /// Creates a new delete account settings entry widget instance.
  const DeleteAccountSettingsEntryWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    User? user = ref.watch(userProvider).value;
    return user == null
        ? const SizedBox.shrink()
        : ClickableTile(
            prefix: const Icon(FIcons.user),
            title: Text(translations.settings.dangerZone.deleteAccount.title),
            subtitle: Text(translations.settings.dangerZone.deleteAccount.subtitle),
            onPress: () async {
              StorageType storageType = await showWaitingOverlay(
                context,
                future: ref.read(storageTypeSettingsEntryProvider.future),
              );
              if (!context.mounted) {
                return;
              }
              if (storageType == .shared) {
                showFDialog(
                  context: context,
                  builder: (context, style, animation) => AppDialog(
                    title: Text(translations.error.errorDialog.title),
                    actions: [
                      ClickableButton(
                        variant: .secondary,
                        onPress: () => Navigator.pop(context),
                        child: ButtonText(MaterialLocalizations.of(context).okButtonLabel),
                      ),
                    ],
                    children: [
                      Text(translations.miscellaneous.disableTotpSync),
                    ],
                  ),
                );
                return;
              }
              await AccountUtils.tryDeleteAccount(context, ref);
            },
          );
  }
}
