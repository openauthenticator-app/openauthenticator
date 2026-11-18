import 'package:flutter/foundation.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_authenticator/core/backend/synchronization/storage_migration.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';
import 'package:open_authenticator/widgets/form/form_label.dart';
import 'package:open_authenticator/widgets/form/password_form_field.dart';

/// The dialog that allows to confirm the operation.
class StorageMigrationConfirmationDialog extends StatefulWidget {
  /// Whether the user wants to enable the data synchronization.
  final bool enable;

  /// Creates a new confirmation dialog instance.
  const StorageMigrationConfirmationDialog({
    super.key,
    required this.enable,
  });

  @override
  State<StatefulWidget> createState() => _StorageMigrationConfirmationDialogState();

  /// Asks for the confirmation.
  static Future<StorageMigrationConfirmationResult?> ask(BuildContext context, bool enable) => showFDialog<StorageMigrationConfirmationResult>(
    context: context,
    builder: (context, style, animation) => StorageMigrationConfirmationDialog(
      enable: enable,
    ),
  );
}

/// The confirmation dialog state.
class _StorageMigrationConfirmationDialogState extends State<StorageMigrationConfirmationDialog> {
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
          Navigator.pop(context, StorageMigrationConfirmationResult(confirm: true, backupPassword: createBackup ? backupPassword : null));
        },
        child: ButtonText(MaterialLocalizations.of(context).continueButtonLabel),
      ),
      ClickableButton(
        variant: .secondary,
        onPress: () => Navigator.pop(context, const StorageMigrationConfirmationResult()),
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
              icon: FLucideIcons.save,
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
    final String password = value ?? backupPasswordController.text;
    if (createBackup && password.isEmpty) {
      return translations.error.validation.empty;
    }
    return null;
  }
}

/// Returned by the [StorageMigrationConfirmationDialog].
class StorageMigrationConfirmationResult {
  /// Whether the user wants to continue.
  final bool confirm;

  /// The backup password.
  final String? backupPassword;

  /// Creates a new confirmation result instance.
  const StorageMigrationConfirmationResult({
    this.confirm = false,
    this.backupPassword,
  });
}

/// Allows the user to choose its [StorageMigrationDeletedTotpPolicy].
class StorageMigrationDeletedTotpPolicyPickerDialog extends StatelessWidget {
  /// Creates a new storage migration deleted TOTP policy picker dialog instance.
  const StorageMigrationDeletedTotpPolicyPickerDialog({
    super.key,
  });

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
        prefix: const Icon(FLucideIcons.trash),
        title: Text(translations.storageMigration.deletedTotpPolicyPickerDialog.delete.title),
        subtitle: Text(translations.storageMigration.deletedTotpPolicyPickerDialog.delete.subtitle),
        onPress: () => Navigator.pop(context, StorageMigrationDeletedTotpPolicy.delete),
      ),
      ClickableTile(
        prefix: const Icon(FLucideIcons.upload),
        title: Text(translations.storageMigration.deletedTotpPolicyPickerDialog.restore.title),
        subtitle: Text(translations.storageMigration.deletedTotpPolicyPickerDialog.restore.subtitle),
        onPress: () => Navigator.pop(context, StorageMigrationDeletedTotpPolicy.keep),
      ),
    ],
  );

  /// Opens the dialog.
  static Future<StorageMigrationDeletedTotpPolicy?> openDialog(BuildContext context) => showFDialog<StorageMigrationDeletedTotpPolicy>(
    context: context,
    builder: (context, style, animation) => const StorageMigrationDeletedTotpPolicyPickerDialog(),
  );
}
