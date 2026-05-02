import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/flows/email_confirmation.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/backend/authentication/providers/provider.dart';
import 'package:open_authenticator/pages/settings/entries/widgets.dart';
import 'package:open_authenticator/widgets/clickable.dart';

/// Allows the user to confirm its email from the app.
class ConfirmEmailSettingsEntryWidget extends ConsumerWidget with FTileMixin {
  /// Creates a new confirm email settings entry widget instance.
  const ConfirmEmailSettingsEntryWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<EmailConfirmationData?> emailToConfirm = ref.watch(emailConfirmationStateProvider);
    return emailToConfirm.value == null
        ? const SizedBox.shrink()
        : ClickableTile(
            prefix: const Icon(FIcons.mail),
            suffix: const RightChevronSuffix(),
            title: Text(translations.settings.synchronization.confirmEmail.title),
            subtitle: Text.rich(
              translations.settings.synchronization.confirmEmail.subtitle(
                email: TextSpan(
                  text: emailToConfirm.value!.email,
                  style: const TextStyle(fontStyle: .italic),
                ),
              ),
            ),
            onPress: () => ref.read(emailConfirmationFlowProvider).askForConfirmation(context),
          );
  }
}
