import 'package:flutter/cupertino.dart';
import 'package:open_authenticator/widgets/dialog/text_input_dialog.dart';
import 'package:open_authenticator/model/app_unlock/interaction.dart';

/// Allows to interact with the app unlock using a [BuildContext].
class _BuildContextAppUnlockInteraction implements AppUnlockInteraction {
  /// The build context.
  final BuildContext context;

  /// Creates a new build context app unlock interaction instance.
  const _BuildContextAppUnlockInteraction(this.context);

  @override
  bool get canInteract => context.mounted;

  @override
  Future<String?> promptMasterPassword({String? message}) async {
    if (!context.mounted) {
      return null;
    }
    return await MasterPasswordInputDialog.prompt(
      context,
      message: message,
    );
  }
}

/// Allows to interact with the app unlock using a [BuildContext].
extension CreateAppUnlockInteraction on BuildContext {
  /// The app unlock interaction.
  AppUnlockInteraction get appUnlockInteraction => _BuildContextAppUnlockInteraction(this);
}
