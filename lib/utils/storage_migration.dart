import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/backend/user.dart';
import 'package:open_authenticator/model/password_verification/password_verification.dart';
import 'package:open_authenticator/model/settings/storage_type.dart';
import 'package:open_authenticator/utils/form_label.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';
import 'package:open_authenticator/widgets/dialog/text_input_dialog.dart';
import 'package:open_authenticator/widgets/form/password_form_field.dart';
import 'package:open_authenticator/widgets/waiting_overlay.dart';

/// Contains some useful methods for migrating storage type.
class StorageMigrationUtils {
  /// Changes the storage type.
  /// Gives some feedback to the user thanks to the [context].
  static Future<Result> changeStorageType(
    BuildContext context,
    WidgetRef ref,
    StorageType newType, {
    bool showConfirmation = true,
    String? backupPassword,
    bool logout = false,
    String? currentStorageMasterPassword,
    StorageMigrationDeletedTotpPolicy storageMigrationDeletedTotpPolicy = .ask,
    bool Function(Result result)? handleResult,
  }) async {
    Result result = await (() async {
      StorageType currentType = await ref.read(storageTypeSettingsEntryProvider.future);
      if (!context.mounted) {
        return const ResultCancelled();
      }
      if (newType != currentType) {
        if (showConfirmation) {
          _ConfirmationResult? result = await _ConfirmationDialog.ask(context, newType == .shared);
          if (result == null || !result.confirm || !context.mounted) {
            return const ResultCancelled();
          }
          backupPassword ??= result.backupPassword;
        }
        Result<bool> passwordCheckResult = await(await ref.read(passwordVerificationProvider.future)).isPasswordValid(currentStorageMasterPassword ?? '');
        if (passwordCheckResult is! ResultSuccess<bool> || !passwordCheckResult.value) {
          if (!context.mounted) {
            return const ResultCancelled();
          }
          String? enteredCurrentStorageMasterPassword = await MasterPasswordInputDialog.prompt(context);
          if (enteredCurrentStorageMasterPassword == null || !context.mounted) {
            return const ResultCancelled();
          }
          currentStorageMasterPassword = enteredCurrentStorageMasterPassword;
        }
      }
      if (!context.mounted) {
        return const ResultCancelled();
      }
      Result result = await showWaitingOverlay(
        context,
        future: ref
            .read(storageTypeSettingsEntryProvider.notifier)
            .changeValue(
              newType,
              masterPassword: currentStorageMasterPassword,
              backupPassword: backupPassword,
              storageMigrationDeletedTotpPolicy: storageMigrationDeletedTotpPolicy,
            ),
      );
      if (!context.mounted) {
        return const ResultCancelled();
      }
      switch (result) {
        case ResultSuccess():
          if (logout) {
            Result logoutResult = await showWaitingOverlay(
              context,
              future: ref.read(userProvider.notifier).logoutUser(),
            );
            result = logoutResult;
          }
          break;
        case ResultError(:final exception):
          if (exception is ShouldAskForDifferentDeletedTotpPolicyException) {
            StorageMigrationDeletedTotpPolicy? enteredStorageMigrationDeletedTotpPolicy = await _StorageMigrationDeletedTotpPolicyPickerDialog.openDialog(context);
            if (enteredStorageMigrationDeletedTotpPolicy == null || !context.mounted) {
              return result;
            }
            return await changeStorageType(
              context,
              ref,
              newType,
              showConfirmation: false,
              logout: logout,
              backupPassword: backupPassword,
              currentStorageMasterPassword: currentStorageMasterPassword,
              storageMigrationDeletedTotpPolicy: enteredStorageMigrationDeletedTotpPolicy,
            );
          }
        default:
          break;
      }
      return result;
    })();
    if ((handleResult?.call(result) ?? true) && context.mounted) {
      context.handleResult(result);
    }
    return result;
  }
}

/// The dialog that allows to confirm the operation.
class _ConfirmationDialog extends StatefulWidget {
  /// Whether the user wants to enable the data synchronization.
  final bool enable;

  /// Creates a new confirmation dialog instance.
  const _ConfirmationDialog({
    required this.enable,
  });

  @override
  State<StatefulWidget> createState() => _ConfirmationDialogState();

  /// Asks for the confirmation.
  static Future<_ConfirmationResult?> ask(BuildContext context, bool enable) => showFDialog<_ConfirmationResult>(
    context: context,
    builder: (context, style, animation) => _ConfirmationDialog(
      enable: enable,
    ),
  );
}

/// The confirmation dialog state.
class _ConfirmationDialogState extends State<_ConfirmationDialog> {
  /// The backup password form key.
  final GlobalKey<FormState> backupPasswordFormKey = GlobalKey<FormState>();

  /// Whether the user wants to create a backup.
  bool createBackup = !kDebugMode;

  /// The backup password.
  String? backupPassword;

  /// The backup password text editing controller.
  late final TextEditingController backupPasswordController = TextEditingController(text: backupPassword);

  @override
  Widget build(BuildContext context) => AppDialog(
    title: Text(translations.storageMigration.confirmDialog.title),
    actions: [
      ClickableButton(
        onPress: () {
          if (createBackup && !backupPasswordFormKey.currentState!.validate()) {
            return;
          }
          Navigator.pop(context, _ConfirmationResult(confirm: true, backupPassword: createBackup ? backupPassword : null));
        },
        child: ButtonText(MaterialLocalizations.of(context).continueButtonLabel),
      ),
      ClickableButton(
        variant: .secondary,
        onPress: () => Navigator.pop(context, const _ConfirmationResult()),
        child: ButtonText(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
    ],
    children: [
      Text(widget.enable ? translations.storageMigration.confirmDialog.message.enable : translations.storageMigration.confirmDialog.message.disable),
      ClickableTile(
        title: Text(translations.miscellaneous.backupCheckbox.checkbox),
        onPress: () {
          setState(() => createBackup = !createBackup);
        },
        suffix: FCheckbox(
          value: createBackup,
          onChange: (value) {
            setState(() => createBackup = value);
          },
        ),
      ),
      if (createBackup)
        Form(
          key: backupPasswordFormKey,
          child: PasswordFormField(
            control: .managed(controller: backupPasswordController),
            validator: isBackupPasswordValid,
            label: FormLabelWithIcon(
              icon: FIcons.save,
              text: translations.miscellaneous.backupCheckbox.input.text,
            ),
            hint: translations.miscellaneous.backupCheckbox.input.hint,
          ),
        ),
    ],
  );

  @override
  void dispose() {
    backupPasswordController.dispose();
    super.dispose();
  }

  /// Checks whether the backup password is valid.
  String? isBackupPasswordValid(String? value) {
    value ??= backupPasswordController.text;
    if (createBackup && value.isEmpty) {
      return translations.error.validation.empty;
    }
    return null;
  }
}

/// Returned by the [_ConfirmationDialog].
class _ConfirmationResult {
  /// Whether the user wants to continue.
  final bool confirm;

  /// The backup password.
  final String? backupPassword;

  /// Creates a new confirmation result instance.
  const _ConfirmationResult({
    this.confirm = false,
    this.backupPassword,
  });
}

/// Allows the user to choose its [StorageMigrationDeletedTotpPolicy].
class _StorageMigrationDeletedTotpPolicyPickerDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) => AppDialog(
    title: Text(translations.storageMigration.deletedTotpPolicyPickerDialog.title),
    actions: [
      ClickableButton(
        variant: .secondary,
        onPress: () => Navigator.pop(context),
        child: ButtonText(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
    ],
    children: [
      Text(translations.storageMigration.deletedTotpPolicyPickerDialog.message),
      ClickableTile(
        prefix: const Icon(FIcons.trash),
        title: Text(translations.storageMigration.deletedTotpPolicyPickerDialog.delete.title),
        subtitle: Text(translations.storageMigration.deletedTotpPolicyPickerDialog.delete.subtitle),
        onPress: () => Navigator.pop(context, StorageMigrationDeletedTotpPolicy.delete),
      ),
      ClickableTile(
        prefix: const Icon(FIcons.upload),
        title: Text(translations.storageMigration.deletedTotpPolicyPickerDialog.restore.title),
        subtitle: Text(translations.storageMigration.deletedTotpPolicyPickerDialog.restore.subtitle),
        onPress: () => Navigator.pop(context, StorageMigrationDeletedTotpPolicy.keep),
      ),
    ],
  );

  /// Opens the dialog.
  static Future<StorageMigrationDeletedTotpPolicy?> openDialog(BuildContext context) => showFDialog<StorageMigrationDeletedTotpPolicy>(
    context: context,
    builder: (context, style, animation) => _StorageMigrationDeletedTotpPolicyPickerDialog(),
  );
}
