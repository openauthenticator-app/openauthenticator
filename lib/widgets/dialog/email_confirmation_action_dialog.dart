import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';

/// Picks for a confirmation action.
class EmailConfirmationActionPickerDialog extends StatelessWidget {
  /// Creates a new email confirmation action picker dialog instance.
  const EmailConfirmationActionPickerDialog({
    super.key,
  });

  @override
  Widget build(BuildContext context) => AppDialog(
    title: Text(translations.emailConfirmation.confirmActionPickerDialog.title),
    actions: [
      ClickableButton(
        variant: .secondary,
        onPress: () => Navigator.pop(context),
        child: ButtonText(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
    ],
    children: [
      ClickableTile(
        prefix: const Icon(FLucideIcons.check),
        title: Text(translations.emailConfirmation.confirmActionPickerDialog.confirm.title),
        subtitle: Text(translations.emailConfirmation.confirmActionPickerDialog.confirm.subtitle),
        onPress: () => Navigator.pop(context, EmailConfirmationAction.tryConfirm),
      ),
      ClickableTile(
        variant: .destructive,
        prefix: const Icon(FLucideIcons.x),
        title: Text(translations.emailConfirmation.confirmActionPickerDialog.cancelConfirmation.title),
        subtitle: Text(translations.emailConfirmation.confirmActionPickerDialog.cancelConfirmation.subtitle),
        onPress: () => Navigator.pop(context, EmailConfirmationAction.cancelConfirmation),
      ),
    ],
  );

  /// Opens the dialog.
  static Future<EmailConfirmationAction?> openDialog(BuildContext context) => showFDialog<EmailConfirmationAction>(
    context: context,
    builder: (context, style, animation) => const EmailConfirmationActionPickerDialog(),
  );
}

/// A [EmailConfirmationActionPickerDialog] result.
enum EmailConfirmationAction {
  /// Tries to confirm the account.
  tryConfirm,

  /// Cancels the confirmation.
  cancelConfirmation,
}
