import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_authenticator/flows/app_flow.dart';
import 'package:open_authenticator/flows/app_unlock_interaction.dart';
import 'package:open_authenticator/model/app_unlock/reason.dart';
import 'package:open_authenticator/model/settings/app_unlock_method.dart';
import 'package:open_authenticator/model/totp/repository.dart';
import 'package:open_authenticator/utils/result/handler.dart';
import 'package:open_authenticator/utils/result/result.dart';
import 'package:open_authenticator/widgets/dialog/change_master_password_dialog.dart';
import 'package:open_authenticator/widgets/waiting_overlay.dart';

/// The master password flow provider.
final Provider<MasterPasswordFlow> masterPasswordFlowProvider = Provider.autoDispose<MasterPasswordFlow>(MasterPasswordFlow.new);

/// Coordinates master password user flows.
class MasterPasswordFlow extends AppFlow {
  /// Creates a new master password flow instance.
  const MasterPasswordFlow(super.ref);

  /// Prompts the user to change his master password.
  Future<Result<String>> changeMasterPassword(
    BuildContext context, {
    bool askForUnlock = true,
    String? password,
  }) => keepAliveWhile(() async {
    if (askForUnlock) {
      final AppUnlockMethodSettingsEntry appUnlockerMethodsSettingsEntry = ref.read(appUnlockMethodSettingsEntryProvider.notifier);
      final Result unlockResult = await appUnlockerMethodsSettingsEntry.unlockWithCurrentMethod(context.appUnlockInteraction, UnlockReason.sensibleAction);
      if (unlockResult is! ResultSuccess) {
        return unlockResult.to((value) => null);
      }
      if (!context.mounted) {
        return const ResultCancelled();
      }
    }
    final ChangeMasterPasswordDialogResult? result = await showFDialog<ChangeMasterPasswordDialogResult>(
      context: context,
      builder: (context, style, animation) => ChangeMasterPasswordDialog(
        defaultPassword: password,
      ),
    );
    if (result == null || result.newPassword == null || !context.mounted) {
      return const ResultCancelled();
    }
    final Result<String> changeResult = await showWaitingOverlay(
      context,
      future: ref.read(totpRepositoryProvider.notifier).changeMasterPassword(result.newPassword!, backupPassword: result.backupPassword),
    );
    if (context.mounted) {
      handleResult(context, changeResult);
    }
    return changeResult;
  });
}
