import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/backend/authentication/providers/provider.dart';
import 'package:open_authenticator/model/backend/backend.dart';
import 'package:open_authenticator/model/backend/request/request.dart';
import 'package:open_authenticator/model/backend/request/response.dart';
import 'package:open_authenticator/model/settings/backend_url.dart';
import 'package:open_authenticator/model/settings/storage_type.dart';
import 'package:open_authenticator/pages/settings/entries/widgets.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:open_authenticator/utils/storage_migration.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';
import 'package:open_authenticator/widgets/dialog/text_input_dialog.dart';
import 'package:open_authenticator/widgets/waiting_overlay.dart';

/// Allows to change the backend URL.
class ChangeBackendUrlSettingsEntryWidget extends ConsumerWidget with FTileMixin {
  /// Creates a new change backend URL settings entry widget instance.
  const ChangeBackendUrlSettingsEntryWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => ClickableTile(
    prefix: const Icon(FIcons.globe),
    suffix: const RightChevronSuffix(),
    title: Text(translations.settings.dangerZone.changeBackendUrl.title),
    subtitle: Text(translations.settings.dangerZone.changeBackendUrl.subtitle),
    onPress: () async {
      StorageType storageType = await showWaitingOverlay(
        context,
        future: ref.read(storageTypeSettingsEntryProvider.future),
      );
      if (!context.mounted) {
        return;
      }
      if (storageType == .shared) {
        await showFDialog(
          context: context,
          builder: (context, style, animation) => AppDialog(
            title: Text(translations.error.widget.title),
            actions: [
              ClickableButton(
                variant: .secondary,
                onPress: () => Navigator.pop(context),
                child: ButtonText(MaterialLocalizations.of(context).okButtonLabel),
              ),
            ],
            children: [
              Text(translations.miscellaneous.disableTotpSync),
            ],
          ),
        );
        return;
      }
      String currentUrl = await showWaitingOverlay(
        context,
        future: ref.read(backendUrlSettingsEntryProvider.future),
      );
      if (!context.mounted) {
        return;
      }
      String? url = await TextInputDialog.prompt(
        context,
        title: translations.settings.dangerZone.changeBackendUrl.inputDialog.title,
        message: translations.settings.dangerZone.changeBackendUrl.inputDialog.message(defaultBackendUrl: App.defaultBackendUrl),
        keyboardType: TextInputType.url,
        initialValue: currentUrl,
        validator: (string) => Uri.tryParse(string ?? '') == null ? translations.error.validation.url : null,
      );
      if (url == null || !context.mounted) {
        return;
      }
      Result<PingBackendResponse> pingBackendResponse = await ref
          .read(backendClientProvider.notifier)
          .sendHttpRequest(
            const PingBackendRequest(),
            backendUrl: url,
          );
      if (!context.mounted) {
        return;
      }
      if (pingBackendResponse is! ResultSuccess<PingBackendResponse>) {
        context.handleResult(
          pingBackendResponse,
          errorMessage: (_) => translations.error.backend.invalidBackendUrl,
          showDialogIfError: (_) => false,
        );
        return;
      }
      StorageType currentStorage = await ref.read(storageTypeSettingsEntryProvider.future);
      if (!context.mounted) {
        return;
      }
      if (currentStorage == .shared) {
        await StorageMigrationUtils.changeStorageType(context, ref, .localOnly, logout: true);
      }
      if (!context.mounted) {
        return;
      }
      await showWaitingOverlay(
        context,
        future: ref.read(emailAuthenticationProvider).cancelConfirmation(),
      );
      if (!context.mounted) {
        return;
      }
      await showWaitingOverlay(
        context,
        future: ref.read(backendUrlSettingsEntryProvider.notifier).changeValue(BackendUrl(url)),
      );
    },
  );
}
