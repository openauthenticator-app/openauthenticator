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
import 'package:open_authenticator/pages/settings/entries/widgets.dart';
import 'package:open_authenticator/utils/result/handler.dart';
import 'package:open_authenticator/utils/result/result.dart';
import 'package:open_authenticator/utils/storage_migration.dart';
import 'package:open_authenticator/widgets/clickable.dart';
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
      Result result = await StorageMigrationUtils.changeStorageType(
        context,
        ref,
        .localOnly,
        logout: true,
        presentation: .successAndErrorToast,
      );
      if (!context.mounted || result is! ResultSuccess) {
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
        keyboardType: .url,
        initialValue: currentUrl,
        validator: (string) => Uri.tryParse(string ?? '') == null ? translations.error.validation.url : null,
      );
      if (url == null || !context.mounted) {
        return;
      }
      Result<PingBackendResponse> pingBackendResponse = await showWaitingOverlay(
        context,
        future: ref
            .read(backendClientProvider.notifier)
            .sendHttpRequest(
              const PingBackendRequest(),
              backendUrl: url,
            ),
      );
      if (!context.mounted) {
        return;
      }
      if (pingBackendResponse is! ResultSuccess<PingBackendResponse>) {
        handleResult(
          context,
          pingBackendResponse,
          buildErrorToastMessage: (_) => translations.error.backend.invalidBackendUrl,
          presentation: .successAndErrorToast,
        );
        return;
      }
      if (!context.mounted) {
        return;
      }
      Result cancelConfirmationResult = await showWaitingOverlay(
        context,
        future: ref.read(authenticationProviders).email.cancelConfirmation(),
      );
      if (!context.mounted) {
        return;
      }
      if (cancelConfirmationResult is! ResultSuccess) {
        handleResult(
          context,
          cancelConfirmationResult,
          presentation: .successAndErrorToast,
        );
        return;
      }
      await showWaitingOverlay(
        context,
        future: ref.read(backendUrlSettingsEntryProvider.notifier).changeValue(BackendUrl(url)),
      );
      if (context.mounted) {
        showSuccessToast(
          context,
          text: translations.error.noError,
        );
      }
    },
  );
}
