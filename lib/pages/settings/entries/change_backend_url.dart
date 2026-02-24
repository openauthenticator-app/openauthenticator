import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/settings/backend_url.dart';
import 'package:open_authenticator/model/settings/storage_type.dart';
import 'package:open_authenticator/pages/settings/entries/widgets.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';
import 'package:open_authenticator/widgets/dialog/text_input_dialog.dart';
import 'package:open_authenticator/widgets/toast.dart';
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
            title: Text(translations.error.errorDialog.title),
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
      );
      if (url == null || !context.mounted) {
        return;
      }
      await showWaitingOverlay(
        context,
        future: ref.read(backendUrlSettingsEntryProvider.notifier).changeValue(url),
      );
      if (context.mounted) {
        showSuccessToast(context, text: translations.error.noError);
      }
    },
  );
}
