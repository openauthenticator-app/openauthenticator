import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_authenticator/utils/account.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';

/// A dialog that asks the user to log-in because of an invalid session.
class InvalidSessionDialog extends ConsumerWidget {
  /// Whether to automatically handle the result.
  final bool handleResult;

  const InvalidSessionDialog._({
    super.key,
    this.handleResult = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppDialog(
    title: const Text('Invalid session'),
    actions: [
      ClickableButton(
        onPress: () => Navigator.pop(context, InvalidSessionDialogChoice.logIn),
        child: const ButtonText('Log-in'),
      ),
      ClickableButton(
        variant: .secondary,
        onPress: () => Navigator.pop(context),
        child: ButtonText(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
    ],
    children: [
      const Text('Your session has either expired or is invalid. Please log-in again to synchronize your TOTPs.'),
    ],
  );

  /// Opens the invalid session dialog.
  static Future<InvalidSessionDialogChoice?> openDialog(BuildContext context, {bool handleResult = false}) async {
    InvalidSessionDialogChoice? result = await showDialog<InvalidSessionDialogChoice>(
      context: context,
      builder: (context) => const InvalidSessionDialog._(),
    );
    if (handleResult && result == .logIn && context.mounted) {
      await AccountUtils.trySignIn(context);
    }
    return result;
  }
}

/// The invalid session dialog result.
enum InvalidSessionDialogChoice {
  /// The user wants to log-in.
  logIn,
}
