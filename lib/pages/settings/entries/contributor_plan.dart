import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/purchases/clients/client.dart';
import 'package:open_authenticator/model/purchases/contributor_plan.dart';
import 'package:open_authenticator/model/settings/backend_url.dart';
import 'package:open_authenticator/utils/contributor_plan.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';
import 'package:open_authenticator/widgets/dialog/error_dialog.dart';
import 'package:open_authenticator/widgets/waiting_overlay.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// Allows the user to subscribe to the Contributor Plan.
class ContributorPlanEntryWidget extends ConsumerWidget with FTileMixin {
  /// Creates a new Contributor Plan entry widget instance.
  const ContributorPlanEntryWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool hasBackendUrlChanged = ref.watch(backendUrlSettingsEntryProvider).value?.hasBackendUrlChanged ?? false;
    AsyncValue<ContributorPlanState> state = hasBackendUrlChanged && !kDebugMode ? const AsyncData(.impossible) : ref.watch(contributorPlanStateProvider);
    switch (state) {
      case AsyncData(:final value):
        switch (value) {
          case .impossible:
            return ClickableTile(
              prefix: const Icon(FIcons.userX),
              title: Text(translations.settings.application.contributorPlan.title),
              subtitle: Text(translations.settings.application.contributorPlan.subtitle.inactive),
              enabled: false,
            );
          case .inactive:
            return ClickableTile(
              prefix: const Icon(FIcons.userLock),
              title: Text(translations.settings.application.contributorPlan.title),
              subtitle: Text(translations.settings.application.contributorPlan.subtitle.inactive),
              onPress: () => ContributorPlanUtils.purchase(context, ref),
            );
          case .active:
            return ClickableTile(
              prefix: const Icon(FIcons.userCheck),
              title: Text(translations.settings.application.contributorPlan.title),
              subtitle: Text(translations.settings.application.contributorPlan.subtitle.active),
              onPress: () => showFDialog(
                context: context,
                builder: (context, style, animation) => AppDialog(
                  title: Text(translations.settings.application.contributorPlan.subscriptionDialog.title),
                  actions: [
                    ClickableButton(
                      variant: .secondary,
                      onPress: () async {
                        String? url = await showWaitingOverlay(
                          context,
                          future: (() async {
                            RevenueCatClient? client = await ref.read(revenueCatClientProvider.future);
                            return client?.getManagementUrl();
                          })(),
                        );
                        if (url != null) {
                          launchUrlString(url);
                          return;
                        }
                        if (context.mounted) {
                          ErrorDialog.openDialog(
                            context,
                            message: translations.settings.application.contributorPlan.subscriptionDialog.manageSubscription.error,
                          );
                        }
                      },
                      child: ButtonText(translations.settings.application.contributorPlan.subscriptionDialog.manageSubscription.button),
                    ),
                    ClickableButton(
                      variant: .secondary,
                      onPress: () => Navigator.pop(context),
                      child: ButtonText(MaterialLocalizations.of(context).closeButtonLabel),
                    ),
                  ],
                  children: [
                    Text(translations.settings.application.contributorPlan.subscriptionDialog.message),
                  ],
                ),
              ),
            );
        }
      case AsyncLoading():
        return ClickableTile(
          prefix: const FCircularProgress(),
          title: Text(translations.settings.application.contributorPlan.title),
          subtitle: Text(translations.settings.application.contributorPlan.subtitle.loading),
          enabled: false,
        );
      case AsyncError():
      default:
        return const SizedBox.shrink();
    }
  }
}
