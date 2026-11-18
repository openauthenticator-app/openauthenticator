import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_authenticator/flows/app_flow.dart';
import 'package:open_authenticator/model/backend/synchronization/storage_migration.dart';
import 'package:open_authenticator/model/backend/user.dart';
import 'package:open_authenticator/model/password_verification/password_verification.dart';
import 'package:open_authenticator/model/settings/storage_type.dart';
import 'package:open_authenticator/utils/result/handler.dart';
import 'package:open_authenticator/utils/result/presentation.dart';
import 'package:open_authenticator/utils/result/result.dart';
import 'package:open_authenticator/widgets/dialog/storage_migration_dialogs.dart';
import 'package:open_authenticator/widgets/dialog/text_input_dialog.dart';
import 'package:open_authenticator/widgets/waiting_overlay.dart';

/// The storage migration flow provider.
final Provider<StorageMigrationFlow> storageMigrationFlowProvider = Provider.autoDispose<StorageMigrationFlow>(StorageMigrationFlow.new);

/// Coordinates storage migration user flows.
class StorageMigrationFlow extends AppFlow {
  /// Creates a new storage migration flow instance.
  const StorageMigrationFlow(super.ref);

  /// Changes the storage type.
  /// Gives some feedback to the user thanks to the [context].
  Future<Result> changeStorageType(
    BuildContext context,
    StorageType newType, {
    bool showConfirmation = true,
    String? backupPassword,
    bool logout = false,
    String? currentStorageMasterPassword,
    StorageMigrationDeletedTotpPolicy storageMigrationDeletedTotpPolicy = .ask,
    ResultPresentation presentation = .successAndErrorDialog,
  }) => keepAliveWhile(() async {
    String? masterPassword = currentStorageMasterPassword;
    final Result result = await (() async {
      final StorageType currentType = await ref.read(storageTypeSettingsEntryProvider.future);
      if (!context.mounted) {
        return const ResultCancelled();
      }
      if (newType != currentType) {
        if (showConfirmation) {
          final StorageMigrationConfirmationResult? result = await StorageMigrationConfirmationDialog.ask(context, newType == .shared);
          if (result == null || !result.confirm || !context.mounted) {
            return const ResultCancelled();
          }
          backupPassword ??= result.backupPassword;
        }
        final Result<bool> passwordCheckResult = await (await ref.read(passwordVerificationProvider.future)).isPasswordValid(masterPassword ?? '');
        if (passwordCheckResult is! ResultSuccess<bool> || !passwordCheckResult.value) {
          if (!context.mounted) {
            return const ResultCancelled();
          }
          final String? enteredCurrentStorageMasterPassword = await MasterPasswordInputDialog.prompt(context);
          if (enteredCurrentStorageMasterPassword == null || !context.mounted) {
            return const ResultCancelled();
          }
          masterPassword = enteredCurrentStorageMasterPassword;
        }
      }
      if (!context.mounted) {
        return const ResultCancelled();
      }
      Result result = await showWaitingOverlay(
        context,
        future: ref
            .read(storageMigratorProvider)
            .migrate(
              newType,
              masterPassword: masterPassword,
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
            final Result logoutResult = await showWaitingOverlay(
              context,
              future: ref.read(userProvider.notifier).logoutUser(),
            );
            result = logoutResult;
          }
          break;
        case ResultError(:final exception):
          if (exception is ShouldAskForDifferentDeletedTotpPolicyException) {
            final StorageMigrationDeletedTotpPolicy? enteredStorageMigrationDeletedTotpPolicy = await StorageMigrationDeletedTotpPolicyPickerDialog.openDialog(context);
            if (enteredStorageMigrationDeletedTotpPolicy == null || !context.mounted) {
              return result;
            }
            return await changeStorageType(
              context,
              newType,
              showConfirmation: false,
              logout: logout,
              backupPassword: backupPassword,
              currentStorageMasterPassword: masterPassword,
              storageMigrationDeletedTotpPolicy: enteredStorageMigrationDeletedTotpPolicy,
              presentation: presentation,
            );
          }
        default:
          break;
      }
      return result;
    })();
    if (context.mounted) {
      handleResult(
        context,
        result,
        presentation: presentation,
      );
    }
    return result;
  });
}
