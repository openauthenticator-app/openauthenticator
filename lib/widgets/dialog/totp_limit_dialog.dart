import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/backend/user.dart';
import 'package:open_authenticator/model/purchases/contributor_plan.dart';
import 'package:open_authenticator/model/settings/storage_type.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/utils/contributor_plan.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:open_authenticator/utils/storage_migration.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/centered_circular_progress_indicator.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';
import 'package:open_authenticator/widgets/dialog/error_dialog.dart';
import 'package:open_authenticator/widgets/waiting_overlay.dart';

/// A dialog that blocks everything until the user has either changed its storage type or subscribed to the Contributor Plan.
class TotpLimitDialog extends ConsumerWidget {
  /// Whether the dialog has been automatically opened.
  final bool autoDialog;

  /// Creates a new mandatory totp limit dialog.
  const TotpLimitDialog({
    super.key,
    required this.autoDialog,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<ContributorPlanState> state = ref.watch(contributorPlanStateProvider);
    if (state is AsyncError<ContributorPlanState>) {
      return ErrorDialog(
        message: translations.totpLimit.message.error,
        error: state.error,
        stackTrace: state.stackTrace,
      );
    }

    if (state is AsyncLoading<ContributorPlanState>) {
      return AppDialog(
        displayCloseButton: !autoDialog,
        children: [
          const CenteredCircularProgressIndicator(),
        ],
      );
    }

    User user = ref.watch(userProvider).value!;
    return AppDialog(
      title: Text(translations.totpLimit.title),
      displayCloseButton: !autoDialog,
      actions: [
        ClickableButton(
          variant: .destructive,
          onPress: () => _returnIfSucceeded(context, StorageMigrationUtils.changeStorageType(context, ref, StorageType.localOnly).then((result) => result is ResultSuccess)),
          child: ButtonText(translations.totpLimit.actions.stopSynchronization),
        ),
        ClickableButton(
          onPress: () => _returnIfSucceeded(context, ContributorPlanUtils.purchase(context, ref)),
          child: ButtonText(translations.totpLimit.actions.subscribe),
        ),
        if (!autoDialog)
          ClickableButton(
            variant: .secondary,
            onPress: () => Navigator.pop(context, false),
            child: ButtonText(translations.totpLimit.actions.cancel),
          ),
      ],
      children: [
        if (state.value == ContributorPlanState.active)
          Text(autoDialog ? translations.totpLimit.message.alreadySubscribed.auto(count: user.totpsLimit) : translations.totpLimit.message.alreadySubscribed.manual(count: user.totpsLimit))
        else
          Text(autoDialog ? translations.totpLimit.message.notSubscribed.auto(count: user.totpsLimit) : translations.totpLimit.message.notSubscribed.manual(count: user.totpsLimit)),
        Padding(
          padding: const EdgeInsets.only(top: kSpace),
          child: ClickableButton(
            variant: .secondary,
            onPress: () async {
              Result<User> result = await showWaitingOverlay(
                context,
                future: ref.read(userProvider.notifier).refreshUserInfo(),
              );
              if (!context.mounted) {
                return;
              }
              context.handleResult(result);
              if (result is ResultSuccess<User> && result.value.contributorPlan) {
                Navigator.pop(context, true);
              }
            },
            child: ButtonText(translations.miscellaneous.refreshUserInfo),
          ),
        ),
      ],
    );
  }

  /// Waits for the [action] result before closing the dialog in case of success.
  Future<void> _returnIfSucceeded(BuildContext context, Future<bool> action) async {
    if ((await action) && context.mounted) {
      Navigator.pop(context, true);
    }
  }

  /// Shows the totp limit dialog and blocks everything until the user has either changed its storage type or subscribed to the Contributor Plan.
  static Future<void> showAndBlock(
    BuildContext context, {
    bool autoDialog = true,
  }) async {
    bool result = false;
    while (!result && context.mounted) {
      result = await show(
        context,
        autoDialog: autoDialog,
      );
    }
  }

  /// Shows the totp limit dialog.
  static Future<bool> show(
    BuildContext context, {
    bool autoDialog = false,
  }) async =>
      (await showFDialog<bool>(
        context: context,
        builder: (context, style, animation) => TotpLimitDialog(
          autoDialog: autoDialog,
        ),
        barrierDismissible: false,
      )) ==
      true;
}
