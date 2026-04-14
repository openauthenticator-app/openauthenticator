import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/app_unlock/reason.dart';
import 'package:open_authenticator/model/backend/user.dart';
import 'package:open_authenticator/model/backup.dart';
import 'package:open_authenticator/model/database/database.dart';
import 'package:open_authenticator/model/settings/app_unlock_method.dart';
import 'package:open_authenticator/model/settings/entry.dart';
import 'package:open_authenticator/model/totp/image_cache.dart';
import 'package:open_authenticator/utils/platform.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:open_authenticator/utils/shared_preferences_with_prefix.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';
import 'package:open_authenticator/widgets/dialog/confirmation_dialog.dart';
import 'package:open_authenticator/widgets/waiting_overlay.dart';
import 'package:simple_secure_storage/simple_secure_storage.dart';

/// Allows to clear all the app data.
class ClearDataSettingsEntryWidget extends ConsumerWidget with FTileMixin {
  /// Creates a new clear data settings entry widget instance.
  const ClearDataSettingsEntryWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => ClickableTile(
    prefix: const Icon(FIcons.trash),
    title: Text(translations.settings.dangerZone.clearData.title),
    subtitle: Text(translations.settings.dangerZone.clearData.subtitle),
    onPress: () async {
      bool confirm = await ConfirmationDialog.ask(
        context,
        title: translations.settings.dangerZone.clearData.confirmationDialog.title,
        message: translations.settings.dangerZone.clearData.confirmationDialog.message,
        okButtonVariant: .destructive,
      );
      if (!confirm || !context.mounted) {
        return;
      }

      AppUnlockMethodSettingsEntry appUnlockerMethodsSettingsEntry = ref.read(appUnlockMethodSettingsEntryProvider.notifier);
      Result unlockResult = await appUnlockerMethodsSettingsEntry.unlockWithCurrentMethod(context, UnlockReason.sensibleAction);
      if (unlockResult is! ResultSuccess || !context.mounted) {
        return;
      }

      bool deleteBackups = await ConfirmationDialog.ask(
        context,
        title: translations.settings.dangerZone.clearData.backupDeleteConfirmationDialog.title,
        message: translations.settings.dangerZone.clearData.backupDeleteConfirmationDialog.message,
        okButtonVariant: .destructive,
      );
      if (!deleteBackups || !context.mounted) {
        return;
      }

      await showWaitingOverlay(
        context,
        future: () async {
          Result logoutResult = await ref.read(userProvider.notifier).logoutUser();
          if (!context.mounted) {
            return;
          }
          if (logoutResult is! ResultSuccess) {
            context.handleResult(logoutResult);
            return;
          }
          await SimpleSecureStorage.clear();
          TotpImageCacheManager totpImageCacheManager = ref.read(totpImageCacheManagerProvider.notifier);
          await totpImageCacheManager.clearCache();
          SharedPreferencesWithPrefix preferences = await ref.read(sharedPreferencesProvider.future);
          await preferences.clear();
          AppDatabase database = ref.read(appDatabaseProvider);
          await database.clear();
          if (deleteBackups) {
            List<Backup> backups = await ref.read(backupStoreProvider.future);
            for (Backup backup in backups) {
              await backup.delete();
            }
          }
        }(),
      );
      if (!context.mounted) {
        return;
      }
      await _showCloseDialog(context);
      if (_canExitWithConfirmDialog) {
        await _closeApp();
      }
    },
  );

  /// Shows the dialog that indicates the user he has to restart the app.
  Future<void> _showCloseDialog(BuildContext context) async {
    bool canExitWithConfirmDialog = _canExitWithConfirmDialog;
    await showFDialog(
      context: context,
      barrierDismissible: false,
      builder: (context, style, animation) => AppDialog(
        title: Text(translations.settings.dangerZone.clearData.doneDialog.title),
        displayCloseButton: false,
        actions: canExitWithConfirmDialog
            ? [
                ClickableButton(
                  variant: .ghost,
                  onPress: () => Navigator.pop(context),
                  child: ButtonText(MaterialLocalizations.of(context).continueButtonLabel),
                ),
              ]
            : null,
        children: [
          Text(
            canExitWithConfirmDialog ? translations.settings.dangerZone.clearData.doneDialog.message.appWillClose : translations.settings.dangerZone.clearData.doneDialog.message.closeAppManually,
          ),
        ],
      ),
    );
  }

  /// Whether we can exit following the [_showCloseDialog] method.
  bool get _canExitWithConfirmDialog => {
    Platform.android,
    Platform.macOS,
    Platform.linux,
    Platform.windows,
  }.contains(currentPlatform);

  /// Closes the app programmatically.
  Future<void> _closeApp() async {
    switch (currentPlatform) {
      case Platform.android:
      case Platform.macOS:
      case Platform.linux:
        await SystemNavigator.pop(animated: true);
        break;
      default:
        debugger();
        exit(0);
    }
  }
}
