import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';

/// A dialog that allows to choose whether to execute an action or not.
class ConfirmationDialog extends StatelessWidget {
  /// The dialog title.
  final String title;

  /// The dialog message.
  final String message;

  /// The variant of the OK button.
  final FButtonVariant? okButtonVariant;

  /// Creates a confirmation dialog instance.
  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.okButtonVariant,
  });

  @override
  Widget build(BuildContext context) => AppDialog(
    title: Text(title),
    actions: [
      ClickableButton(
        variant: okButtonVariant ?? .primary,
        onPress: () => Navigator.pop(context, true),
        child: ButtonText(MaterialLocalizations.of(context).okButtonLabel),
      ),
      ClickableButton(
        variant: .secondary,
        onPress: () => Navigator.pop(context, false),
        child: ButtonText(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
    ],
    children: [
      Text(message),
    ],
  );

  /// Asks for the confirmation.
  static Future<bool> ask(
    BuildContext context, {
    required String title,
    required String message,
    FButtonVariant? okButtonVariant,
  }) async =>
      (await showFDialog<bool>(
        context: context,
        builder: (context, style, animation) => ConfirmationDialog(
          title: title,
          message: message,
          okButtonVariant: okButtonVariant,
        ),
      )) ==
      true;
}
