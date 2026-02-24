import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/app_unlock/reason.dart';
import 'package:open_authenticator/model/settings/app_unlock_method.dart';
import 'package:open_authenticator/model/totp/repository.dart';
import 'package:open_authenticator/utils/form_label.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';
import 'package:open_authenticator/widgets/form/master_password_form.dart';
import 'package:open_authenticator/widgets/form/password_form_field.dart';
import 'package:open_authenticator/widgets/waiting_overlay.dart';

/// Contains various useful methods about the master password.
class MasterPasswordUtils {
  /// Prompts the user to change his master password.
  static Future<Result<String>> changeMasterPassword(
    BuildContext context,
    WidgetRef ref, {
    bool askForUnlock = true,
    String? password,
  }) async {
    if (askForUnlock) {
      AppUnlockMethodSettingsEntry appUnlockerMethodsSettingsEntry = ref.read(appUnlockMethodSettingsEntryProvider.notifier);
      Result unlockResult = await appUnlockerMethodsSettingsEntry.unlockWithCurrentMethod(context, UnlockReason.sensibleAction);
      if (unlockResult is! ResultSuccess) {
        return unlockResult.to((value) => null);
      }
      if (!context.mounted) {
        return const ResultCancelled();
      }
    }
    _ChangeMasterPasswordDialogResult? result = await showDialog<_ChangeMasterPasswordDialogResult>(
      context: context,
      builder: (context) => _ChangeMasterPasswordDialog(
        defaultPassword: password,
      ),
    );
    if (result == null || result.newPassword == null || !context.mounted) {
      return const ResultCancelled();
    }
    Result<String> changeResult = await showWaitingOverlay(
      context,
      future: ref.read(totpRepositoryProvider.notifier).changeMasterPassword(result.newPassword!, backupPassword: result.backupPassword),
    );
    if (context.mounted) {
      context.handleResult(changeResult);
    }
    return changeResult;
  }
}

/// The dialog that allows to change the master password.
class _ChangeMasterPasswordDialog extends ConsumerStatefulWidget {
  /// The default password.
  final String? defaultPassword;

  /// Creates a new change master password dialog instance.
  const _ChangeMasterPasswordDialog({
    this.defaultPassword,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ChangeMasterPasswordDialogState();
}

/// The change master password dialog state.
class _ChangeMasterPasswordDialogState extends ConsumerState<_ChangeMasterPasswordDialog> {
  /// The new password form key.
  final GlobalKey<FormState> newPasswordFormKey = GlobalKey<FormState>();

  /// The new password value.
  late String newPassword = widget.defaultPassword ?? '';

  /// Whether the user wants to create a backup.
  bool createBackup = !kDebugMode;

  /// The backup password form key.
  final GlobalKey<FormState> backupPasswordFormKey = GlobalKey<FormState>();

  /// The backup password text editing controller.
  late final TextEditingController backupPasswordController = TextEditingController();

  @override
  Widget build(BuildContext context) => AppDialog(
    title: Text(translations.masterPassword.changeDialog.title),
    actions: [
      ClickableButton(
        onPress: () async {
          if (!newPasswordFormKey.currentState!.validate() || (createBackup && !backupPasswordFormKey.currentState!.validate())) {
            return;
          }
          if (context.mounted) {
            Navigator.pop(
              context,
              _ChangeMasterPasswordDialogResult(
                newPassword: newPassword,
                backupPassword: createBackup ? backupPasswordController.text : null,
              ),
            );
          }
        },
        child: ButtonText(MaterialLocalizations.of(context).continueButtonLabel),
      ),
      ClickableButton(
        variant: .secondary,
        onPress: () => Navigator.pop(context),
        child: ButtonText(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
    ],
    children: [
      MasterPasswordForm(
        formKey: newPasswordFormKey,
        defaultPassword: widget.defaultPassword,
        inputText: translations.masterPassword.changeDialog.newLabel,
        onChanged: (value) => newPassword = value ?? '',
      ),
      FCheckbox(
        label: Text(translations.miscellaneous.backupCheckbox.checkbox),
        value: createBackup,
        onChange: (value) {
          setState(() => createBackup = value);
        },
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

/// Returned by the [_ChangeMasterPasswordDialog].
class _ChangeMasterPasswordDialogResult {
  /// The new password.
  final String? newPassword;

  /// The backup password.
  final String? backupPassword;

  /// Creates a new confirmation result instance.
  const _ChangeMasterPasswordDialogResult({
    this.newPassword,
    this.backupPassword,
  });
}
