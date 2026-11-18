import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_authenticator/flows/app_unlock_interaction.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/app_unlock/reason.dart';
import 'package:open_authenticator/model/backend/user.dart';
import 'package:open_authenticator/model/backup/backup.dart';
import 'package:open_authenticator/model/database/database.dart';
import 'package:open_authenticator/model/secure_storage.dart';
import 'package:open_authenticator/model/settings/app_unlock_method.dart';
import 'package:open_authenticator/model/settings/entry.dart';
import 'package:open_authenticator/model/totp/image_cache.dart';
import 'package:open_authenticator/utils/platform.dart';
import 'package:open_authenticator/utils/result/handler.dart';
import 'package:open_authenticator/utils/result/result.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';
import 'package:open_authenticator/widgets/dialog/confirmation_dialog.dart';
import 'package:open_authenticator/widgets/waiting_overlay.dart';

/// Allows to clear all the app data.
class ClearDataSettingsEntryWidget extends ConsumerWidget with FTileMixin {
  /// Creates a new clear data settings entry widget instance.
  const ClearDataSettingsEntryWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => ClickableTile(
    prefix: const Icon(FLucideIcons.trash),
    title: Text(translations.settings.dangerZone.clearData.title),
    subtitle: Text(translations.settings.dangerZone.clearData.subtitle),
    onPress: () async {
      final bool confirm = await ConfirmationDialog.ask(
        context,
        title: translations.settings.dangerZone.clearData.confirmationDialog.title,
        message: translations.settings.dangerZone.clearData.confirmationDialog.message,
        okButtonVariant: .destructive,
      );
      if (!confirm || !context.mounted) {
        return;
      }

      final AppUnlockMethodSettingsEntry appUnlockerMethodsSettingsEntry = ref.read(appUnlockMethodSettingsEntryProvider.notifier);
      final Result unlockResult = await appUnlockerMethodsSettingsEntry.unlockWithCurrentMethod(context.appUnlockInteraction, UnlockReason.sensibleAction);
      if (unlockResult is! ResultSuccess || !context.mounted) {
        return;
      }

      final bool? deleteBackups = await showFDialog<bool>(
        context: context,
        builder: (context, style, animation) => AppDialog(
          title: Text(translations.settings.dangerZone.clearData.backupDeleteConfirmationDialog.title),
          actions: [
            ClickableButton(
              variant: .destructive,
              onPress: () => Navigator.pop(context, true),
              child: ButtonText(translations.storageMigration.deletedTotpPolicyPickerDialog.delete.title),
            ),
            ClickableButton(
              variant: .secondary,
              onPress: () => Navigator.pop(context, false),
              child: ButtonText(translations.storageMigration.deletedTotpPolicyPickerDialog.restore.title),
            ),
          ],
          children: [Text(translations.settings.dangerZone.clearData.backupDeleteConfirmationDialog.message)],
        ),
      );
      if (deleteBackups == null || !context.mounted) {
        return;
      }
      final Result result = await showWaitingOverlay(context, future: _clear(ref, deleteBackups));
      if (!context.mounted) {
        return;
      }
      if (result is! ResultSuccess) {
        handleResult(context, result, presentation: .errorDialog);
        return;
      }
      await _showCloseDialog(context);
      if (_canExitWithConfirmDialog) {
        await _closeApp();
      }
    },
  );

  Future<Result> _clear(WidgetRef ref, bool deleteBackups) async {
    try {
      final Result<dynamic> logout = await ref.read(userProvider.notifier).logoutUser();
      if (logout is! ResultSuccess) {
        return logout;
      }
      await (await ref.read(secureStorageProvider.future)).clear();
      await ref.read(totpImageCacheManagerProvider.notifier).clearCache();
      await (await ref.read(sharedPreferencesProvider.future)).clear();
      await ref.read(appDatabaseProvider).clear();
      if (deleteBackups) {
        for (final BackupPath backup in await ref.read(backupStoreProvider.future)) {
          final Result<dynamic> result = await ref.read(backupStoreProvider.notifier).deleteBackup(backup);
          if (result is! ResultSuccess) {
            return result;
          }
        }
      }
      return const ResultSuccess();
    } catch (error, stackTrace) {
      return ResultError(exception: error, stackTrace: stackTrace);
    }
  }

  /// Shows the dialog that indicates the user he has to restart the app.
  Future<void> _showCloseDialog(BuildContext context) async {
    final bool canExitWithConfirmDialog = _canExitWithConfirmDialog;
    await showFDialog(
      context: context,
      barrierDismissible: false,
      builder: (context, style, animation) => AppDialog(
        title: Text(translations.settings.dangerZone.clearData.doneDialog.title),
        displayCloseButton: false,
        actions: canExitWithConfirmDialog
            ? [
                ClickableButton(
                  variant: .secondary,
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
