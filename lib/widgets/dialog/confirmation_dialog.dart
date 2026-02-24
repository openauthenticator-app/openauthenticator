import 'package:flutter/material.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';

/// A dialog that allows to choose whether to execute an action or not.
class ConfirmationDialog extends StatelessWidget {
  /// The dialog title.
  final String title;

  /// The dialog message.
  final String message;

  /// Creates a confirmation dialog instance.
  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) => AppDialog(
    title: Text(title),
    actions: [
      ClickableButton(
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
  }) async =>
      (await showDialog<bool>(
        context: context,
        builder: (context) => ConfirmationDialog(
          title: title,
          message: message,
        ),
      )) ==
      true;
}
